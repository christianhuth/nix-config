# Package set changes applied on top of nixpkgs. Wired in from flake.nix, so
# anything below is visible as plain `pkgs.<name>` in the rest of the config.
final: prev: {
  # Overrides nixpkgs' snap-based Termius with a build from the official .deb.
  termius = final.callPackage ./termius/package.nix { };
}
