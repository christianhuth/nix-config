# Packages that should be available to EVERY user of this machine.
#
# On NixOS this would simply be `environment.systemPackages`. Since we are on
# Ubuntu, we instead bundle the packages into ONE derivation (buildEnv) and
# install that into the system profile at /nix/var/nix/profiles/default.
# See README.md.
{ pkgs }:

pkgs.buildEnv {
  name = "system-packages";

  paths = with pkgs; [
    # Firefox, preconfigured to use a self-hosted Sync server.
    #
    # `extraPrefs` is appended to the autoconfig file mozilla.cfg inside the
    # package itself, so it applies to EVERY user who starts this Firefox --
    # unlike user.js, which lives in a profile and is therefore per-user.
    #
    # defaultPref() replaces the built-in default but still lets the value be
    # changed in about:config. Use lockPref() instead to make it immutable.
    (firefox.override {
      extraPrefs = ''
        defaultPref("identity.sync.tokenserver.uri", "https://firefox.knell.it/token/1.0/sync/1.5");
      '';
    })

    thunderbird
    gimp # 3.x; `gimp-with-plugins` is available as well
    spotify # unfree -> see allowUnfree in flake.nix
    nextcloud-client # the desktop sync client, not the Nextcloud server
  ];

  # Pull man pages and docs into the profile, not just the binaries.
  extraOutputsToInstall = [
    "man"
    "doc"
  ];
}
