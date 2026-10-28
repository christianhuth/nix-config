{
  description = "Nix configuration for christianhuth (NixOS, and Ubuntu 26.04 via standalone Home Manager)";

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

    # Declarative KDE Plasma settings for Home Manager -- NixOS only, the
    # Ubuntu machine runs GNOME. Used by home/features/plasma.nix.
    plasma-manager = {
      url = "github:nix-community/plasma-manager";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.home-manager.follows = "home-manager";
    };
  };

  outputs =
    {
      nixpkgs,
      nixpkgs-unstable,
      home-manager,
      nix-vscode-extensions,
      plasma-manager,
      ...
    }:
    let
      system = "x86_64-linux";
      username = "christianhuth";
      inherit (nixpkgs) lib;

      # A second package set, only drawn from where a stable pin would hurt.
      unstable = import nixpkgs-unstable {
        inherit system;
        config.allowUnfree = true;
      };

      # Shared by both platforms: on Ubuntu they go into the pkgs instance
      # below, on NixOS into `nixpkgs.overlays` (see mkHost).
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

      # One single pkgs instance, shared by both Ubuntu layers.
      # allowUnfree is required for Spotify and the Claude Code extension.
      pkgs = import nixpkgs {
        inherit system overlays;
        config.allowUnfree = true;
      };

      # Ubuntu's layer 1: the shared package list bundled into ONE derivation,
      # because off NixOS there is no environment.systemPackages to put it in.
      systemPackages = pkgs.buildEnv {
        name = "system-packages";
        paths = import ./system/packages.nix { inherit pkgs; };

        # Pull man pages and docs into the profile, not just the binaries.
        extraOutputsToInstall = [
          "man"
          "doc"
        ];
      };

      # === NixOS =======================================================
      # Every directory under hosts/ is one machine: the installer's
      # configuration.nix and hardware-configuration.nix, copied in verbatim, plus
      # users.nix (see hosts/README.md). Naming the directory after the hostname
      # means `sudo nixos-rebuild switch --flake .` picks it without a #name.
      hosts = lib.attrNames (
        lib.filterAttrs (_: type: type == "directory") (builtins.readDir ./hosts)
      );

      # A feature name resolves to one Home Manager module. This is the whole
      # indirection: hosts/<hostname>/users.nix lists names, nothing else.
      featureModule = name: ./home/features + "/${name}.nix";

      mkHost =
        hostname:
        let
          # { <user> = [ "feature" ... ]; } -- which users this machine has, and
          # what each of them gets on it. The same user can carry a different set
          # on a different machine; that is the point of keeping it here rather
          # than in users/ or home/.
          hostUsers = import (./hosts + "/${hostname}/users.nix");
        in
        lib.nixosSystem {
          modules = [
            # Machine-specific, from the installer: boot loader, LUKS devices,
            # file systems, locale, desktop, the user accounts.
            (./hosts + "/${hostname}/configuration.nix")

            # Shared system layer -- what apt and the manual steps in
            # README.md did on Ubuntu.
            ./system/nixos.nix
          ]

          # System-level identity (uid, gid, groups) for each user on this
          # machine. Shared across machines, hence users/ and not hosts/.
          ++ map (name: ./users + "/${name}.nix") (lib.attrNames hostUsers)

          ++ [
            home-manager.nixosModules.home-manager
            {
              # Deliberately NOT `nixpkgs.pkgs = pkgs`: the installer writes
              # `nixpkgs.config.allowUnfree = true` into configuration.nix, and
              # NixOS refuses nixpkgs.config next to an externally created
              # instance. Configuring NixOS's own instance merges cleanly.
              nixpkgs.overlays = overlays;
              nixpkgs.config.allowUnfree = true;

              home-manager = {
                # Home Manager uses the system's pkgs (with the overlays above)
                # instead of evaluating a second nixpkgs.
                useGlobalPkgs = true;
                # Packages land in /etc/profiles/per-user/<name> instead of
                # ~/.nix-profile.
                useUserPackages = true;
                # Same job as `-b backup` on Ubuntu, but for every switch.
                backupFileExtension = "backup";

                # `username` is NOT passed here on purpose -- it is set per user
                # below, so a module can never see a different user's name. Only
                # the standalone Ubuntu output, which has exactly one user, passes
                # it as a specialArg.
                extraSpecialArgs.isNixOS = true;

                # Makes the programs.plasma.* options available to every user.
                # Only declares them -- nothing changes until a module sets
                # programs.plasma.enable, which home/features/plasma.nix does.
                # Not imported from that feature itself, because a feature
                # module has no access to the flake inputs.
                sharedModules = [ plasma-manager.homeModules.plasma-manager ];

                # Every user gets the shared base plus their own features. All
                # users in ONE `nixos-rebuild switch` -- the separate,
                # easy-to-forget root switch from Ubuntu is gone.
                users =
                  lib.mapAttrs (name: features: {
                    # Shared base, the features this user picked on this machine,
                    # and -- if it exists -- that machine's own per-user settings.
                    #
                    # hosts/<hostname>/home.nix is the place for Home Manager
                    # configuration that belongs to the *hardware* rather than to a
                    # user or a feature: touchpad device ids, display scaling,
                    # keyboard layout. Those cannot be features, because a feature is
                    # meant to be reusable across machines, and they do not belong in
                    # home/ for the same reason. Optional, so a host without quirks
                    # needs no such file.
                    imports =
                      [ ./home/default.nix ]
                      ++ map featureModule features
                      ++ lib.optional (builtins.pathExists (./hosts + "/${hostname}/home.nix")) (
                        ./hosts + "/${hostname}/home.nix"
                      );

                    # The right name for *this* user. Home Manager's NixOS module
                    # also derives home.username and home.homeDirectory from
                    # users.users.<name>; both definitions agree, and `types.str`
                    # merges equal values, so this stays a cross-check rather than
                    # a conflict. It would fail loudly if a home directory were
                    # ever not /home/<name>.
                    _module.args.username = name;
                  }) hostUsers
                  // {
                    root = ./home/root.nix;
                  };
              };
            }
          ];
        };
    in
    {
      # === NixOS: system + both Home Manager users in one switch ==========
      #   sudo nixos-rebuild switch --flake .
      nixosConfigurations = lib.genAttrs hosts mkHost;

      # Everything below is for Ubuntu, where Nix runs next to apt. On NixOS
      # the same files are wired in through mkHost above instead.

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

        extraSpecialArgs = {
          inherit username;
          isNixOS = false;
        };
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
        extraSpecialArgs.isNixOS = false;
      };
    };
}
