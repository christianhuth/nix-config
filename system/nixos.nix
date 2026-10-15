# The shared system layer on NixOS. Imported by every host in flake.nix, next
# to that host's own configuration.nix from the installer.
#
# Everything here was apt's job, or a manual step in README.md, on Ubuntu --
# the "Nix cannot reach this" walls the home/ modules describe. On NixOS they
# are ordinary options.
{ config, pkgs, ... }:

{
  # === Layer 1 ==========================================================
  # The same list the Ubuntu system profile is built from.
  environment.systemPackages = import ./packages.nix { inherit pkgs; } ++ [
    # Ubuntu ships python3 in its base system and the managed .envrc in
    # home/code.nix relies on that (`layout_python3`). NixOS has no system
    # python3, so it has to be named here.
    pkgs.python3
  ];

  # Firefox comes from system/packages.nix with the Sync server preference.
  # The installer adds its own, unconfigured one via programs.firefox; with
  # both, which `firefox` ends up in PATH is down to collision order, so fail
  # loudly instead.
  assertions = [
    {
      assertion = !config.programs.firefox.enable;
      message = ''
        programs.firefox.enable is set -- the installer writes it into
        configuration.nix. Firefox already comes from system/packages.nix,
        preconfigured for the Sync server; a second, plain Firefox would
        compete with it. Delete that line from hosts/<hostname>/configuration.nix.
      '';
    }
  ];

  # `nix run`, `nix develop` and direnv's `use flake` all need these.
  # (nixos-rebuild --flake enables them for itself, so the very first switch
  # works without this already being active.)
  nix.settings.experimental-features = [
    "nix-command"
    "flakes"
  ];

  # === ykman (home/yubikey.nix) ===========================================
  # The two prerequisites that were `apt install pcscd yubikey-personalization`:
  # pcscd for the PIV, OATH and OpenPGP applets, and Yubico's 69-yubikey.rules
  # so the OTP interface gets the uaccess tag, not just the FIDO one.
  services.pcscd.enable = true;
  services.udev.packages = [ pkgs.yubikey-personalization ];

  # === Docker (home/ddev.nix, home/containerlab.nix) ======================
  # The same split as on Ubuntu, without apt and the setuptool dance:
  #
  #   rootless  for christianhuth -- what ddev talks to. A user unit, started
  #             with the session; the subuid/subgid ranges come from
  #             isNormalUser automatically.
  #   rootful   for containerlab only, which needs root anyway (veth pairs and
  #             netns in the host namespace) and runs through sudo, see
  #             home/containerlab.nix.
  #
  # christianhuth is deliberately NOT in the `docker` group -- that is still
  # root-equivalent, exactly as README.md argues for Ubuntu.
  #
  # One difference: setSocketVariable exports DOCKER_HOST pointing at the
  # rootless socket. On Ubuntu that was avoided in favour of the "rootless"
  # CLI context the setuptool creates; NixOS creates no context, and the
  # variable is how its module wires the CLI up. sudo drops it, so
  # `sudo containerlab` still reaches the rootful daemon.
  virtualisation.docker.enable = true;
  virtualisation.docker.rootless = {
    enable = true;
    setSocketVariable = true;
  };

  # === containerlab (home/containerlab.nix) ===============================
  # The group exists here because it is system-wide; who is *in* it is part of a
  # user's identity and lives in users/<name>.nix.
  #
  # Both groups exist for the VSCodium extension, not for the CLI -- `sudo
  # containerlab` needs neither. The extension checks real group membership at
  # activation time (execSync("id -nG")) and refuses to start otherwise:
  #
  #   inClabAdmins = groups.includes("clab_admins")
  #   inDocker     = groups.includes("docker")
  #   allowed = inClabAdmins && (runtime === "docker" ? inDocker
  #                              : runtime === "podman" ? true : false)
  #
  #   -> "Extension activation failed. Insufficient permissions.
  #       Ensure <user> is in the 'clab_admins' and 'docker' group(s)."
  #
  # containerlab itself also knows the group ("user '%v' is not part of
  # containerlab admin group 'clab_admins'") and skips the check when it does not
  # exist -- so it is created explicitly rather than left implicit.
  #
  # Be aware what `docker` membership means: with virtualisation.docker.enable
  # above it is root-equivalent, because a member can ask the rootful daemon to
  # bind-mount / into a privileged container. This is the same trade-off README.md
  # spells out for Ubuntu, made deliberately so the extension works. Two ways out
  # if that is ever unwanted:
  #
  #   * set `containerlab.runtime = "podman"` in home/vscodium.nix -- the gate
  #     above then needs clab_admins only, no docker group at all;
  #   * or drop the extension and drive the CLI through sudo, which needs neither.
  #
  # ddev is unaffected either way: it reaches the rootless daemon through
  # DOCKER_HOST, which needs no group membership.
  users.groups.clab_admins = { };
}
