# Packages that should be available to EVERY user of this machine.
#
# A plain list, used on both platforms:
#
#   NixOS   system/nixos.nix puts it into environment.systemPackages.
#   Ubuntu  flake.nix bundles it into ONE derivation (buildEnv) that gets
#           installed into the system profile at /nix/var/nix/profiles/default.
#
# See README.md.
{ pkgs }:

with pkgs;
[
  # Firefox, preconfigured to use a self-hosted Sync server.
  #
  # `extraPrefs` is appended to the autoconfig file mozilla.cfg inside the
  # package itself, so it applies to EVERY user who starts this Firefox --
  # unlike user.js, which lives in a profile and is therefore per-user.
  #
  # defaultPref() replaces the built-in default but still lets the value be
  # changed in about:config. Use lockPref() instead to make it immutable.
  #
  # On NixOS this replaces `programs.firefox.enable`, which the installer
  # writes into configuration.nix -- system/nixos.nix asserts it is gone.
  (firefox.override {
    extraPrefs = ''
      defaultPref("identity.sync.tokenserver.uri", "https://firefox.knell.it/token/1.0/sync/1.5");
    '';
  })

  thunderbird
  gimp # 3.x; `gimp-with-plugins` is available as well
  spotify # unfree -> see allowUnfree in flake.nix
  nextcloud-client # the desktop sync client, not the Nextcloud server
]
