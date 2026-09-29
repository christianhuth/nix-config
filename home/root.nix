# Entry point for the root user. Referenced from flake.nix as
# homeConfigurations.root, and applied separately -- as root -- rather than by the
# switch for christianhuth. Two users means two Home Manager generations.
#
# Deliberately narrow: the shell and the prompt, nothing else. Everything root
# needs beyond that already comes from the system profile (layer 1).
{ ... }:

{
  imports = [
    # Both are user-agnostic: bash.nix references no username or user-specific
    # path, and starship.nix only describes the prompt. Reusing them keeps the two
    # shells consistent instead of drifting apart.
    ./bash.nix
    ./starship.nix
  ];

  home.username = "root";
  home.homeDirectory = "/root";
  home.stateVersion = "26.05";

  programs.home-manager.enable = true;

  # Not imported here, in contrast to home/default.nix:
  #
  #   targets.genericLinux.enable -- it exists to put the Nix profiles into
  #   XDG_DATA_DIRS so desktop entries and icons are found, and it pulls in the
  #   non-nixos-gpu helper. A root shell needs neither.
}
