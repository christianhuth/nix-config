{ pkgs, ... }:

let
  ini = pkgs.formats.ini { };
in
{
  home.packages = with pkgs; [
    # `pass-wayland` is plain pass with waylandSupport enabled. The override only
    # adds Wayland and leaves x11Support at its default, so `pass -c` copies via
    # wl-copy in the Wayland session and still works for XWayland applications.
    pass-wayland

    # Required by the credential.helper configured in home/git.nix.
    pass-git-helper
  ];

  # Host-to-entry mapping for pass-git-helper. Section names are fnmatch
  # patterns matched against the host git asks about; `target` is the path of
  # the entry inside the password store.
  #
  # Written as an attribute set rather than raw text so adding a host is a line
  # of Nix instead of hand-edited INI. pass-git-helper parses this with Python's
  # configparser, which ignores the whitespace around `=` that the generator
  # produces.
  #
  # Note the consequence of managing it here: the file becomes a symlink into
  # the Nix store and is therefore read-only. New hosts get added in this file
  # and applied with `home-manager switch`, not by editing ~/.config directly.
  xdg.configFile."pass-git-helper/git-pass-mapping.ini".source =
    ini.generate "git-pass-mapping.ini" {
      "gitlab.proact.eu*".target = "proact/gitlab.proact.eu";
    };

  # Installs gnupg -- 2.4.9, which shadows Ubuntu's 2.4.8 because
  # ~/.nix-profile/bin comes first in PATH (see README.md) -- and writes
  # ~/.gnupg/gpg.conf with Home Manager's hardening defaults. There was no
  # gpg.conf here before, so nothing gets overwritten. `mutableKeys` and
  # `mutableTrust` default to true, so the existing keyring and trustdb are
  # left alone.
  programs.gpg.enable = true;

  # Takes the agent over from Ubuntu. Home Manager writes
  # ~/.config/systemd/user/gpg-agent.*, which takes precedence over Ubuntu's
  # units in /usr/lib/systemd/user -- so this is a clean handover, not a
  # conflict. It also silences
  #   gpg: WARNING: server 'gpg-agent' is older than us (2.4.8 < 2.4.9)
  # which appeared while the client came from Nix and the agent from Ubuntu.
  services.gpg-agent = {
    enable = true;

    # Emits exactly
    #   GPG_TTY="$(tty)"
    #   export GPG_TTY
    # into the interactive section of the generated ~/.bashrc. This is why that
    # snippet is no longer set by hand here.
    enableBashIntegration = true;

    # nixpkgs builds gnupg with guiSupport = false on Linux, so no pinentry path
    # is compiled in and the agent would use whatever `pinentry` happens to be
    # in PATH -- currently Ubuntu's. Pin it instead. pinentry-gnome3 fits this
    # GNOME/Wayland session; if a prompt ever fails to appear, adding pkgs.gcr
    # to home.packages is the documented fix and pkgs.pinentry-curses the
    # fallback.
    pinentry.package = pkgs.pinentry-gnome3;

    # Deliberately not enabled: enableSshSupport would make gpg-agent replace
    # ssh-agent and take over SSH key handling. That is a separate decision from
    # managing GnuPG.
  };
}
