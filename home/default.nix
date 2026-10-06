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
    ./atuin.nix # atuin shell history (needs bash.nix for its integration)
    ./bash.nix # bash itself + ~/.bashrc, ~/.profile, ~/.bash_profile
    ./code.nix # ~/code directory layout + the ansible .envrc
    ./containerlab.nix # containerlab (needs a rootful Docker, see the file)
    ./ddev.nix # ddev + mkcert (needs Docker from apt, see the file)
    ./devenv.nix # devenv (note: not wired into direnv's lib, see the file)
    ./direnv.nix # direnv + nix-direnv (needs bash.nix for its hook)
    ./fonts.nix # fontconfig + the Nerd Font starship needs
    ./git.nix # git + its configuration
    ./gnupg.nix # pass, gnupg, and GPG_TTY
    ./kubeswitch.nix # kubeswitch (needs bash.nix for its shell function)
    ./starship.nix # prompt (owns PS1; see bash.nix)
    ./krew.nix # krew + its plugins
    ./vscodium.nix # VSCodium + extensions
    ./wireguard.nix # wireguard-tools + NetworkManager import
    ./yubikey.nix # ykman (plus the system prerequisites it needs)
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

    # Astral's Python package manager. Note how it interacts with the
    # `layout_python3` in home/code.nix's .envrc: direnv's layout builds a plain
    # virtualenv from whatever python3 is in PATH, and uv operates inside it.
    uv

    # Provides `ansible-galaxy` along with `ansible`, `ansible-playbook`,
    # `ansible-vault` and the rest.
    #
    # Careful with the naming here, it is the reverse of what it looks like:
    # `pkgs.ansible` is ansible-**core** (2.21.1), i.e. engine plus CLI without
    # the community collections. There is no top-level `pkgs.ansible-core`. The
    # full bundle with ~100 collections preinstalled is
    # `python3Packages.ansible` (13.7.0).
    #
    # Core is the deliberate choice: collections belong per project via
    # ansible-galaxy and a requirements.yml, which is what ansible-galaxy is for.
    ansible
  ];
}
