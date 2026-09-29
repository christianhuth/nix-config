{
  description = "Nix configuration for christianhuth (Ubuntu 26.04, not NixOS)";

  inputs = {
    # Stable channel -- the baseline for everything here.
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";

    # Used for individual packages that must not lag behind, see pkgs/overlay.nix.
    nixpkgs-unstable.url = "github:NixOS/nixpkgs/nixos-unstable";

    home-manager = {
      url = "github:nix-community/home-manager/release-26.05";
      # Make Home Manager use exactly the same nixpkgs as above.
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # VSCodium extensions. nixpkgs' vscode-extensions set lags badly on some of
    # them -- gitlens sat at 17.11.1 there while upstream was at 19.2.0 -- and
    # that gap is what let VSCodium overrule the declared versions. This flake
    # mirrors Open VSX and the VS Code marketplace daily. See home/vscodium.nix.
    nix-vscode-extensions = {
      url = "github:nix-community/nix-vscode-extensions";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    {
      nixpkgs,
      nixpkgs-unstable,
      home-manager,
      nix-vscode-extensions,
      ...
    }:
    let
      system = "x86_64-linux";
      username = "christianhuth";

      # A second package set, only drawn from where a stable pin would hurt.
      unstable = import nixpkgs-unstable {
        inherit system;
        config.allowUnfree = true;
      };

      # One single pkgs instance, shared by both layers.
      # allowUnfree is required for Spotify and the Claude Code extension.
      pkgs = import nixpkgs {
        inherit system;
        config.allowUnfree = true;

        overlays = [
          # Our own packages and overrides.
          (import ./pkgs/overlay.nix { inherit unstable; })

          # Adds open-vsx{,-release}, vscode-marketplace{,-release} and friends
          # to pkgs. Applied as an overlay rather than reading the flake's
          # `extensions` output directly, because that output is built from the
          # flake's own nixpkgs instance -- which has no allowUnfree, and the
          # Claude Code extension is unfree. Going through our pkgs fixes that.
          nix-vscode-extensions.overlays.default
        ];
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

        # Exposed so it can be built and tested on its own, which is handy
        # after a version bump:  nix build .#termius && ./result/bin/termius-app
        inherit (pkgs) termius;
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

      # === root ==========================================================
      # Only the shell and the prompt -- see home/root.nix. This is a separate
      # Home Manager generation under /root and has to be applied as root:
      #
      #   sudo /nix/var/nix/profiles/default/bin/nix run home-manager/release-26.05 \
      #     -- switch --flake /home/christianhuth/code/christianhuth/nix-config#root
      #
      # The absolute paths are not decoration: sudo's secure_path contains neither
      # the Nix profile nor christianhuth's, and root's cwd is not this repository.
      homeConfigurations.root = home-manager.lib.homeManagerConfiguration {
        inherit pkgs;
        modules = [ ./home/root.nix ];
      };
    };
}
