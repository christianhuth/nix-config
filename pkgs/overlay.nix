# Package set changes applied on top of nixpkgs. Wired in from flake.nix, so
# anything below is visible as plain `pkgs.<name>` in the rest of the config.
#
# `unstable` is the nixos-unstable package set, passed in by flake.nix.
{ unstable }:

final: prev: {
  # Overrides nixpkgs' snap-based Termius with a build from the official .deb.
  termius = final.callPackage ./termius/package.nix { };

  # Signal Desktop carries a hard expiry: roughly 90 days after its build date
  # it refuses to start ("this version has expired"). Pinning it to the stable
  # channel therefore does not just mean missing features, it means the program
  # stops working. Track unstable for this one and refresh with `nix flake
  # update` -- the versions in stable are regularly too old to be usable.
  inherit (unstable) signal-desktop;

  # devenv moves fast and nixpkgs 26.05 sits at 2.1.2 while upstream released
  # 2.4.0 (2026-09-24), which is exactly what unstable carries. Three minor
  # versions matter here because devenv.nix options and the module schema change
  # between them -- an old binary rejects a current devenv.nix with a version
  # error rather than degrading gracefully.
  inherit (unstable) devenv;

  # containerlab: 26.05 carries 0.71.0, unstable 0.78.2. The node images it
  # starts are built from vrnetlab's master branch (see homelab/network/lab),
  # and vrnetlab and containerlab change together -- an old containerlab
  # against a current vrnetlab image is the combination nobody tests.
  inherit (unstable) containerlab;
}
