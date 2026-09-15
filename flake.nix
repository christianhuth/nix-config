{
  description = "Nix configuration for christianhuth (Ubuntu 26.04, not NixOS)";

  inputs = {
    # Stable channel. Switch to "nixos-unstable" for newer packages.
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";

    home-manager = {
      url = "github:nix-community/home-manager/release-26.05";
      # Make Home Manager use exactly the same nixpkgs as above.
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    { nixpkgs, home-manager, ... }:
    let
      system = "x86_64-linux";
      username = "christianhuth";

      # One single pkgs instance, shared by both layers.
      # allowUnfree is required for Spotify and the Claude Code extension.
      pkgs = import nixpkgs {
        inherit system;
        config.allowUnfree = true;
      };

      systemPackages = import ./system/packages.nix { inherit pkgs; };
    in
    {
      # === Layer 1: system-wide, for every user =========================
      # Package list: system/packages.nix
      #   sudo nix profile install .#system-packages
      packages.${system} = {
        system-packages = systemPackages;
        default = systemPackages;
      };

      # === Layer 2: for this user only ==================================
      # Package list: home/default.nix (attribute `home.packages`)
      #   home-manager switch --flake .#christianhuth
      homeConfigurations.${username} = home-manager.lib.homeManagerConfiguration {
        inherit pkgs;

        # Written out on purpose. Just `./home` would work too -- Nix would
        # pick up home/default.nix implicitly -- but the full path makes it
        # obvious where the per-user configuration actually starts.
        modules = [ ./home/default.nix ];

        extraSpecialArgs = { inherit username; };
      };
    };
}
