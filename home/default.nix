# Entry point for everything that belongs to THIS user only.
# Referenced from flake.nix as homeConfigurations."christianhuth".
#
# Per-user packages come from two places:
#
#   1. `home.packages` below -- the plain list, for tools that need no
#      further configuration.
#   2. The imported modules below. A `programs.<name>.enable = true` installs
#      its own package as a side effect -- that covers bash, git, kubeswitch
#      and VSCodium -- and home/krew.nix adds krew through its own
#      `home.packages`. That is why none of those appear in the list below.
#
{ pkgs, username, ... }:

{
  imports = [
    ./bash.nix # bash itself + ~/.bashrc, ~/.profile, ~/.bash_profile
    ./git.nix # git + its configuration
    ./gnupg.nix # pass, gnupg, and GPG_TTY
    ./kubeswitch.nix # kubeswitch (needs bash.nix for its shell function)
    ./krew.nix # krew + its plugins
    ./vscodium.nix # VSCodium + extensions
    ./wireguard.nix # wireguard-tools + NetworkManager import
  ];

  home.username = username;
  home.homeDirectory = "/home/${username}";

  # Records which defaults this configuration was written against.
  # Do NOT bump this casually -- read the Home Manager release notes first.
  home.stateVersion = "26.05";

  # We are on Ubuntu, not NixOS. This sets XDG_DATA_DIRS to point at the Nix
  # profiles so GNOME finds .desktop files and icons -- without it, Spotify
  # and friends never show up in the application menu.
  targets.genericLinux.enable = true;

  # Makes `home-manager` itself available as a command.
  programs.home-manager.enable = true;

  # === Packages for christianhuth only ==================================
  home.packages = with pkgs; [
    # --- GUI ------------------------------------------------------------
    headlamp
    signal-desktop
    teams-for-linux # Microsoft discontinued the official Linux client

    # Built from the vendor's official .deb, not from nixpkgs' snap-based
    # package -- see pkgs/termius/package.nix for why. unfree; the binary is
    # called `termius-app`, not `termius`.
    termius

    # --- Network / VPN --------------------------------------------------
    netbird

    # --- Kubernetes -----------------------------------------------------
    kubectl
    kubernetes-helm # careful: the `helm` attribute is a synthesizer!
    k9s
    kind
    minikube
    clusterctl
    kargo
    kubevirt # provides `virtctl`

    # --- Development ----------------------------------------------------
    gh
    php84Packages.composer # there is no top-level `composer` attribute
  ];
}
