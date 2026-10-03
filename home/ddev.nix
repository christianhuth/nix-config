{ pkgs, ... }:

{
  home.packages = with pkgs; [
    # Provides `ddev`, `ddev-hostname` (its /etc/hosts helper, which needs sudo)
    # and `ddev_gen_autocomplete`.
    #
    # From 26.05 at 1.25.3 against 1.25.4 upstream -- a single patch, so the
    # stable channel is fine here. Contrast devenv, which is pulled from unstable
    # because 26.05 lags it by three minor versions.
    ddev

    # ddev uses mkcert to create a local CA so that *.ddev.site gets trusted
    # HTTPS. A hard requirement rather than a nicety: ddev does not bundle it,
    # and the package's closure carries only docker-buildx -- neither docker nor
    # mkcert.
    mkcert
  ];

  # ddev is a thin orchestrator on top of a container runtime, and Nix cannot
  # supply one here. pkgs.docker exists and includes the daemon, but running
  # dockerd on Ubuntu means a systemd unit and a root-owned socket -- the same
  # wall as pcscd in home/yubikey.nix. apt owns the runtime; Nix owns everything
  # above it.
  #
  # The runtime is **rootless** Docker from Ubuntu's docker.io. Not the docker
  # group: membership there lets you ask the root-owned daemon to bind-mount / into
  # a privileged container, so it is root-equivalent, not a "non-root docker".
  # Rootless runs dockerd as christianhuth inside a user namespace instead.
  #
  # ddev supports that explicitly -- its binary carries IsDockerRootless,
  # getDockerRootlessHostIP and a RootlessKit network-driver probe, and names the
  # context in its own error text ("Check: DOCKER_CONTEXT=rootless docker ps").
  #
  # Setup is a one-off outside Nix; README.md ("Docker has to come from apt") has
  # the full walkthrough with the reasoning. The short form:
  #
  #   sudo apt install docker.io uidmap rootlesskit slirp4netns
  #   sudo gpasswd -d "$USER" docker          # root-equivalent, and unneeded
  #   sudo systemctl disable --now docker.service docker.socket
  #   # log out and back in, then:
  #   sudo ln -s /usr/share/docker.io/contrib/dockerd-rootless.sh /usr/bin/
  #   dockerd-rootless-setuptool.sh install
  #   systemctl --user enable --now docker
  #   sudo loginctl enable-linger "$USER"
  #   mkcert -install                         # once, for *.ddev.site
  #
  # The symlink is not cosmetic. The setuptool derives its install dir from
  # `dirname $(command -v dockerd-rootless.sh)` and then calls "$BIN/docker" for the
  # readiness wait and for creating the CLI context. Upstream that works because
  # Docker CE ships both in ~/bin; Ubuntu splits them (/usr/bin vs
  # /usr/share/docker.io/contrib). Prefixing PATH with the contrib dir therefore
  # yields a working daemon but NO "rootless" context. Symlinking into /usr/bin
  # makes both resolve. See README.md for the repair if you hit it.
  #
  # Deliberately NOT set here: DOCKER_HOST. The setuptool already creates and
  # activates a CLI context named "rootless" that both docker and ddev read, so the
  # variable is redundant -- and it is not inert, because DOCKER_HOST overrides the
  # context and would make a later `docker context use` silently do nothing.
  #
  # One rootless limit worth knowing: ports below 1024 need either
  # net.ipv4.ip_unprivileged_port_start=0 system-wide, or ddev's router moved up
  # with `ddev config global --router-http-port=8080 --router-https-port=8443`.
  # (ddev 1.25.3 no longer needs --no-bind-mounts; that was 1.25.0-1.25.2.)
  #
  # Note on state: ddev writes ~/.ddev/global_config.yaml, project_list.yaml and a
  # homeadditions/ tree on first run, and rewrites them through `ddev config
  # global`. They are deliberately not declared here -- Nix managing a file the
  # tool itself keeps rewriting is the trap that already cost a round with atuin's
  # config.toml.
}
