{ pkgs, ... }:

{
  home.packages = [
    # Provides `ykman`. Note the attribute name is `yubikey-manager`, the binary
    # is `ykman`. nixpkgs 26.05 has 5.9.1, newer than Ubuntu's apt 5.8.0-4.
    pkgs.yubikey-manager
  ];

  # What Nix can and cannot do here, because `ykman` alone is not a working setup.
  # Measured on this machine with a YubiKey 5 (USB 1050:0407, OTP+U2F+CCID)
  # plugged in:
  #
  #   /dev/hidraw1   ACL christianhuth:rw-    FIDO interface, works
  #   /dev/hidraw0   crw------- root root     OTP interface, no access
  #
  # The asymmetry comes from udev. systemd's 70-uaccess.rules line 60 reads
  #
  #   ENV{ID_SECURITY_TOKEN}=="?*", TAG+="uaccess"
  #
  # and 60-fido-id.rules only sets that variable on the FIDO interface. Yubico's
  # own 69-yubikey.rules sets it by USB product id, so it covers the OTP interface
  # too -- product 0407 is listed explicitly.
  #
  # Two prerequisites are therefore Ubuntu's job, not Nix's. Both are system-level
  # (a udev rule in /etc, a daemon with a systemd unit), which off NixOS is outside
  # what Home Manager can reach:
  #
  #   sudo apt install pcscd                   # PIV, OATH and OpenPGP applets
  #   sudo apt install yubikey-personalization  # ships 69-yubikey.rules -> OTP applet
  #
  # Without pcscd the CCID applets are invisible to ykman; without the udev rule
  # `ykman otp` cannot open the device. FIDO/WebAuthn works without either.
  #
  # One interaction to be aware of given home/gnupg.nix: gpg-agent's scdaemon and
  # pcscd both want the card, and they can lock each other out ("card busy"). If
  # the OpenPGP applet is ever used from gpg, `programs.gpg.scdaemonSettings` is
  # where that gets settled -- typically `disable-ccid = true` so scdaemon goes
  # through pcscd instead of driving the reader itself.
}
