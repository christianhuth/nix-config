{ pkgs, ... }:

{
  home.packages = [
    # From nixos-unstable via pkgs/overlay.nix, not from 26.05 -- see the comment
    # there. Used by ~/code/christianhuth/homelab/network/lab.
    pkgs.containerlab
  ];

  # containerlab does NOT work with the rootless Docker from home/ddev.nix. It
  # wires its nodes together with veth pairs and network namespaces that it
  # creates in the host namespace, so it has to run as root and talk to a
  # rootful daemon (/var/run/docker.sock). Nix cannot provide that daemon here
  # -- same wall as in home/ddev.nix.
  #
  # sudo's secure_path does not contain ~/.nix-profile, so call it as
  #
  #   sudo "$(command -v containerlab)" ...
  #
  # which is what the homelab's lab.sh does.
}
