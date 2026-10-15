# The system-level identity of christianhuth: what has to be the same on every
# machine that has this user. Which *configuration* they get is a separate
# question, answered per machine in hosts/<hostname>/users.nix.
#
# This does NOT create the account on a machine where the installer already
# declared it -- hosts/<hostname>/configuration.nix carries the password hash and
# the description, and both halves merge. A user the installer never wrote (a new
# one, on a new machine) needs `isNormalUser = true;` added here.
{ ... }:

{
  users.users.christianhuth = {
    # Pinned, not left to the dynamic allocator. NixOS hands out uids from
    # /var/lib/nixos/uid-map, which is stable per machine but NOT guaranteed
    # identical across machines. Anything carrying numeric ownership -- a backup,
    # an external disk, a home directory restored from the Ubuntu laptop -- would
    # otherwise need chown -R. 1000 is what Ubuntu already uses here.
    uid = 1000;

    # For the VSCodium containerlab extension, which checks real group membership
    # at activation time. `sudo containerlab` needs neither group; the reasoning
    # and the two ways out live in system/nixos.nix next to the group itself.
    extraGroups = [
      "clab_admins"
      "docker"
    ];
  };

  users.groups.christianhuth.gid = 1000;
}
