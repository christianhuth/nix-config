{
  pkgs,
  isNixOS,
  # Only passed when Home Manager runs as a NixOS module, hence the default.
  osConfig ? null,
  ...
}:

let
  # seahorse's askpass. A graphical askpass is needed because the VSCodium
  # extension runs containerlab through child_process, so there is no terminal for
  # a password prompt (see the findings below).
  #
  # On Ubuntu, Ubuntu's copy, deliberately: seahorse is already installed there
  # and costs nothing extra; the Nix alternatives were measured and are not worth
  # their closure for a password dialog:
  #
  #   lxqt.lxqt-openssh-askpass   773M
  #   ssh-askpass-fullscreen      182M
  #   x11_ssh_askpass              43M   (binary lives in libexec, not bin)
  #
  # If it is ever missing there: sudo apt install seahorse
  #
  # On NixOS: whatever the system already decided, rather than a package named
  # here. Measured reason -- the desktops disagree, and hardcoding picks a fight
  # with whichever machine is not the one you were thinking of:
  #
  #   programs/seahorse.nix:28                  GNOME  -> seahorse's ssh-askpass
  #   services/desktop-managers/plasma6.nix:265 Plasma -> ksshaskpass
  #
  # Both set `programs.ssh.askPassword` with mkDefault, so reading it back gets
  # the one that fits. The NixOS laptop runs Plasma; pinning seahorse here would
  # have put a GNOME askpass over its ksshaskpass and dragged a 388M closure onto
  # a machine that has no other use for it.
  askpass =
    if isNixOS then
      osConfig.programs.ssh.askPassword
    else
      "/usr/libexec/seahorse/ssh-askpass";

  clab = "${pkgs.containerlab}/bin/containerlab";

  # Elevating wrapper, so the extension can drive a Nix-installed containerlab.
  #
  # Point `containerlab.binaryPath` at this (done below). It replaces the SUID bit
  # that upstream's installer sets and that a store path can never carry:
  # /nix/store holds 0 setuid files by design -- Nix canonicalises store
  # permissions to 444/555 root:root and strips setuid/setgid, because store paths
  # travel through binary caches where a setuid bit would be an escalation vector.
  # NixOS closes that gap with `security.wrappers`; off NixOS there is no
  # equivalent, which is why this wrapper exists.
  #
  # On NixOS it is kept anyway: a setuid containerlab via security.wrappers
  # would hand root to everyone in its group, which is the same security
  # decision as joining `docker` (see below) and is not made implicitly. sudo
  # works the same way there, from /run/wrappers/bin.
  #
  # Note sudo itself has to be the system's: a Nix-built sudo could not be setuid
  # for exactly the same reason. writeShellApplication only *prefixes* PATH with
  # runtimeInputs, so /usr/bin/sudo stays reachable.
  containerlab-root = pkgs.writeShellApplication {
    name = "containerlab-root";
    runtimeInputs = [ pkgs.coreutils ];
    text = ''
      # Already root (e.g. called from a root shell): nothing to do.
      if [ "$(id -u)" -eq 0 ]; then
        exec ${clab} "$@"
      fi

      # These read nothing privileged. Keeping them unelevated matters: the
      # extension runs `containerlab version check` on every activation, and
      # elevating that would pop a password dialog each time VSCodium starts.
      # `__complete` is what the shell completion calls on every Tab press.
      case "''${1-}" in
        version | completion | __complete | __completeNoDesc | generate | help | --help | -h | "")
          exec ${clab} "$@"
          ;;
      esac

      # Interactive use (your homelab lab.sh, or a plain shell): prompt inline.
      if [ -t 0 ] && [ -t 1 ]; then
        exec sudo -- ${clab} "$@"
      fi

      # No terminal: this is the extension calling us. Hand the prompt to the GUI
      # helper. sudo caches the credential for ~15 minutes, so a deploy followed by
      # a destroy asks only once.
      if [ ! -x "${askpass}" ]; then
        echo "containerlab-root: no terminal, and no askpass helper at ${askpass}" >&2
        echo "containerlab-root: run 'sudo apt install seahorse', or call containerlab from a terminal" >&2
        exit 1
      fi

      # VSCodium installed as a snap points GTK_PATH at its own bundled GTK modules
      # (/snap/codium/<rev>/usr/lib/x86_64-linux-gnu/gtk-3.0). seahorse's askpass is
      # a GTK program, loads those, and dies before drawing anything:
      #
      #   symbol lookup error: /snap/core20/.../libpthread.so.0:
      #   undefined symbol: __libc_pthread_init, version GLIBC_PRIVATE
      #
      # Measured here, not hypothetical -- the running VSCodium is the snap, so the
      # extension passes that environment down. Unsetting GTK_PATH alone is enough;
      # the companion module caches go too since they point into the snap as well.
      # None of this is needed once VSCodium comes from Nix instead of snap.
      unset GTK_PATH GTK_IM_MODULE_FILE GIO_MODULE_DIR GDK_PIXBUF_MODULE_FILE
      unset LD_LIBRARY_PATH LD_PRELOAD

      SUDO_ASKPASS="''${SUDO_ASKPASS:-${askpass}}"
      export SUDO_ASKPASS
      exec sudo -A -- ${clab} "$@"
    '';
  };

  # What goes on PATH: the wrapper under containerlab's own names, plus the
  # package's shell completions. So `containerlab deploy` (and `clab`) just
  # works without sudo in front, like upstream's sudo-less SUID install -- and
  # `sudo containerlab` would not find it anyway, since sudo's secure_path does
  # not contain the Nix profile. The unwrapped binary is the store path in
  # `clab` above.
  containerlab-cli = pkgs.symlinkJoin {
    name = "containerlab-cli-${pkgs.containerlab.version}";
    # From nixos-unstable via pkgs/overlay.nix, not from 26.05 -- see the
    # comment there. Used by ~/code/christianhuth/homelab/network/lab.
    paths = [
      containerlab-root
      pkgs.containerlab
    ];
    postBuild = ''
      rm "$out/bin/containerlab"
      ln -s ${containerlab-root}/bin/containerlab-root "$out/bin/containerlab"
      ln -s ${containerlab-root}/bin/containerlab-root "$out/bin/clab"
    '';
  };
in

{
  home.packages = [ containerlab-cli ];

  # containerlab does NOT work with the rootless Docker from home/ddev.nix. It
  # wires its nodes together with veth pairs and network namespaces that it
  # creates in the host namespace, so it has to run as root and talk to a
  # rootful daemon (/var/run/docker.sock). On Ubuntu, Nix cannot provide that
  # daemon -- same wall as in home/ddev.nix. On NixOS, system/nixos.nix runs
  # it next to the rootless one.
  #
  # The VSCodium extension (srl-labs.vscode-containerlab, see home/vscodium.nix)
  # cannot use that workaround, and will not work on this machine. Three findings
  # from its bundle, recorded so this is not re-investigated:
  #
  # 1. It invokes the binary directly and never prefixes sudo -- the whole bundle
  #    contains exactly one `sudo`, in the install hint it offers when no binary is
  #    found. So every deploy/destroy hits the same "requires root privileges or
  #    root via SUID" that the note above works around by hand. Upstream's own
  #    installer sets the SUID bit; /nix/store is read-only and Nix does not set
  #    SUID bits, and `security.wrappers` only exists on NixOS.
  #
  # 2. Activation is gated on two system groups. For a non-root user:
  #
  #      inClabAdmins = groups.includes("clab_admins")
  #      inDocker     = groups.includes("docker")
  #      allowed = inClabAdmins && (runtime === "docker" ? inDocker
  #                                 : runtime === "podman" ? true : false)
  #
  #    Otherwise it aborts with "Extension activation failed. Insufficient
  #    permissions." Here `clab_admins` does not exist and `docker` is empty,
  #    because we left it when moving to rootless Docker (see README.md).
  #
  # 3. It reads Docker through dockerode with an explicit socketPath:
  #
  #      let r = config.get("dockerSocketPath", "/var/run/docker.sock");
  #      let s = new Dockerode({ socketPath: r });
  #
  #    Passing socketPath explicitly bypasses dockerode's DOCKER_HOST handling, so
  #    `containerlab.dockerSocketPath` is the only lever -- and it has to name the
  #    same daemon containerlab used. Since containerlab runs as root against the
  #    rootful socket, the default is already the right value; pointing it at the
  #    rootless socket would connect and show nothing.
  #
  # Making the extension work therefore means re-enabling rootful Docker and
  # rejoining `docker` (root-equivalent once a rootful daemon listens), plus
  # creating `clab_admins` and installing containerlab from upstream's installer so
  # it carries SUID -- at which point this Nix copy would shadow it, since
  # ~/.nix-profile/bin precedes /usr/bin. That is a security decision, so nothing
  # here makes it implicitly. The CLI path above keeps working either way.

  # The extension resolves the binary from this setting before falling back to
  # `which containerlab`. Both are the elevating wrapper by now; the setting
  # just pins it to the store path.
  programs.vscodium.profiles.default.userSettings."containerlab.binaryPath" =
    "${containerlab-root}/bin/containerlab-root";
}
