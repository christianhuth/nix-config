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
}
