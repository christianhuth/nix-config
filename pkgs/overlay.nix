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
}
