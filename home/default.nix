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
{
  pkgs,
  username,
  isNixOS,
  ...
}:

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
    ./ssh.nix # SSH_ASKPASS, so the FIDO2 key works without a TTY
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

  # Ubuntu only. This sets XDG_DATA_DIRS to point at the Nix profiles so GNOME
  # finds .desktop files and icons -- without it, Spotify and friends never
  # show up in the application menu. NixOS wires its profiles in itself.
  #
  # `isNixOS` comes from extraSpecialArgs in flake.nix, set per output: true
  # for the Home Manager instances inside nixosConfigurations, false for the
  # standalone homeConfigurations used on Ubuntu.
  targets.genericLinux.enable = !isNixOS;

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

    # Office suite, for reading and editing .docx/.xlsx/.pptx.
    #
    # Not OpenOffice: Apache OpenOffice has been effectively dormant for years
    # and is not in nixpkgs at all (`openoffice` and `apache-openoffice` are both
    # missing attributes). LibreOffice is the fork that kept moving.
    #
    # This attribute is the conservative branch -- nixpkgs maps `libreoffice` to
    # libreoffice-still, currently 25.8.5.2. `libreoffice-fresh` is 26.2.1.2 and
    # carries newer import filters, which can matter for documents from recent
    # Office versions; swap the name if a file ever renders wrongly.
    #
    # There is also a Qt build (`libreoffice-qt6`, `libreoffice-qt6-fresh`). It
    # is the better fit on the Plasma machine -- native file dialogs and theming
    # instead of GTK ones -- but picking per machine needs a per-host feature
    # rather than this shared list, so it is deliberately not done here yet.
    #
    # The matching fonts are NOT in this package -- measured, it contains zero
    # .ttf files -- so they are installed separately in home/fonts.nix. Without
    # them a .docx in Calibri reflows, because substitution picks a face with
    # different metrics and line and page breaks move.
    libreoffice

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

    # Moved out of home/krew.nix. Only these three keep working *exactly* as
    # before, because their binary name is what kubectl looks for: krew installs
    # kubectl-explore, kubectl-tree and kubectl-view_secret, and nixpkgs ships
    # the same names. `kubectl view-secret` still resolves, since kubectl
    # retries a dashed subcommand with underscores.
    #
    # The win is that these are now part of the generation instead of being
    # downloaded by krew on every activation.
    kubectl-explore
    kubectl-tree
    kubectl-view-secret # binary: kubectl-view_secret

    # Cluster inspection and reporting. All verified to be the tool meant here
    # rather than a name collision -- `nova` in particular is Fairwinds', not
    # OpenStack's.
    kubespy # pulumi/kubespy, observe resources in real time
    kubetail # johanhaleby/kubetail -- NOT krew's `tail`, which is kail
    nova # Fairwinds, finds outdated Helm releases
    pluto # Fairwinds, finds deprecated apiVersions

    # OpenShift client. The attribute is `openshift`; the binary is `oc`.
    openshift

    # --- Development ----------------------------------------------------
    gh
    php84Packages.composer # there is no top-level `composer` attribute

    # Astral's Python package manager. Note how it interacts with the
    # `layout_python3` in home/code.nix's .envrc: direnv's layout builds a plain
    # virtualenv from whatever python3 is in PATH, and uv operates inside it.
    uv

    # mikefarah's yq, which is the one nearly everything means by `yq`.
    # Deliberately NOT `pkgs.yq`: that is the Python wrapper around jq and
    # provides `yq`, `tomlq` and `xq`. Both would install a binary called `yq`,
    # so they cannot be combined.
    yq-go

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
