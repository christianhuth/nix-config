# SSH_ASKPASS. Not an aesthetic choice -- without it, every non-interactive ssh
# against the FIDO2 key fails.
#
# ~/.ssh/proact is an `sk-ssh-ed25519@openssh.com` key, i.e. the private half
# lives on the YubiKey (see home/yubikey.nix) and was created with PIN
# verification required. OpenSSH therefore has to prompt for the PIN on *every*
# signature. With a terminal it asks inline; without one it calls $SSH_ASKPASS,
# and if that is unset it falls back to the compiled-in default
# /usr/bin/ssh-askpass.
#
# Nothing provides that path on this machine:
#
#   $ update-alternatives --display ssh-askpass
#   update-alternatives: error: no alternatives for ssh-askpass
#
# so ansible-playbook -- which never gives ssh a TTY -- died with
#
#   ssh_askpass: exec(/usr/bin/ssh-askpass): No such file or directory
#   christian@<ip>: Permission denied (publickey,password).
#
# The second line is the consequence, not a separate problem: the key could not
# be used, so ssh fell through to password auth, which also had no way to ask.
#
# Pointing at seahorse's helper, which is already installed (and is the same one
# home/containerlab.nix uses for sudo -A -- keep the two in sync if it moves).
# Ubuntu's, not Nix's, for the same reason as there: the Nix askpass packages
# measured 773M (lxqt), 182M (ssh-askpass-fullscreen) and 43M (x11_ssh_askpass)
# of closure, which is absurd for a password dialog. The apt alternative would be
# `sudo apt install ssh-askpass-gnome`, which registers /usr/bin/ssh-askpass
# through update-alternatives and would make this variable unnecessary.
#
# SSH_ASKPASS_REQUIRE is deliberately NOT set: left alone, OpenSSH prefers a
# terminal when it has one and only reaches for the helper when it does not,
# which is exactly the wanted behaviour. Setting it to "prefer" would pop a GUI
# dialog even for interactive ssh in a terminal.
#
# Note ~/.ssh/config is not managed here -- it is hand-maintained and holds host
# entries, so it stays mutable.
#
# NixOS needs none of this, which is why the variable is only set off NixOS
# rather than switched to a Nix path. NixOS derives it already:
#
#   programs.seahorse.enable          -- GNOME sets this (gnome.nix: "programs.
#                                        seahorse.enable = notExcluded pkgs.seahorse")
#     -> programs.ssh.askPassword     = "${pkgs.seahorse}/libexec/seahorse/ssh-askpass"
#     -> environment.variables.SSH_ASKPASS  (programs/ssh.nix)
#
# Setting it here anyway would not be harmless: hm-session-vars.sh is sourced
# from ~/.profile, i.e. AFTER environment.variables, so Home Manager always
# wins. A hardcoded value would silently override whatever the system derived --
# including the correct one, and any later change to programs.ssh.askPassword or
# an `environment.gnome.excludePackages` that drops seahorse.
{ lib, isNixOS, ... }:

{
  home.sessionVariables = lib.mkIf (!isNixOS) {
    SSH_ASKPASS = "/usr/libexec/seahorse/ssh-askpass";
  };
}
