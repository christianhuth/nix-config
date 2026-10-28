# Home Manager settings that belong to THIS machine rather than to a user or a
# feature. Imported by flake.nix for every user on this host, if it exists.
#
# What qualifies: anything keyed to the hardware. A feature is meant to be
# reusable on another machine; a touchpad's device ids are not.
{ ... }:

{
  # The touchpad scrolled the opposite way from the Ubuntu laptop, because
  # Plasma defaults natural scrolling to off while GNOME has it on. These values
  # mirror what org.gnome.desktop.peripherals.touchpad had there:
  #
  #   natural-scroll true, tap-to-click true, disable-while-typing true, speed 0
  #
  # This has to go through plasma-manager, not services.libinput: that option
  # writes an Xorg InputClass and is tied to services.xserver.enable, while the
  # session here is Wayland, where KWin reads kcminputrc instead.
  programs.plasma.input.touchpads = [
    {
      enable = true;

      # From /proc/bus/input/devices. Give the ids as **hex**, the way they
      # appear there -- plasma-manager converts them itself with
      # `lib.fromHexString` to build the kcminputrc section name, here
      # Libinput/1739/52544/<name>. The example in plasma-manager's own option
      # shows the already-converted decimals, which is a good way to end up
      # writing settings for a device that does not exist. Case does not matter.
      name = "SYNA7DB5:01 06CB:CD40 Touchpad";
      vendorId = "06cb";
      productId = "cd40";

      naturalScroll = true;
      tapToClick = true;
      disableWhileTyping = true;
      pointerSpeed = 0;
    }
  ];
}
