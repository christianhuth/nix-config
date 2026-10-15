# hosts/

One directory per NixOS machine, named after its hostname. `flake.nix` turns
every directory here into `nixosConfigurations.<name>`, so on that machine

```bash
sudo nixos-rebuild switch --flake .
```

picks the right one by hostname, without `#<name>`.

| File | What it carries |
| ---------------------------- | ---------------------------------------------------------------------- |
| `hardware-configuration.nix` | file systems, the root LUKS device, kernel modules for this hardware |
| `configuration.nix` | boot loader, **the swap LUKS device**, hostname, locale, keymap, desktop, the user accounts, `system.stateVersion` |
| `users.nix` | which users this machine has, and which features each of them gets |

The first two are the files the installer wrote to `/etc/nixos`, copied verbatim.
Keep them as they are. In particular, the installer puts the encrypted **swap**
device into `configuration.nix`, not into `hardware-configuration.nix`
(`nixos-generate-config` does not detect it), so replacing `configuration.nix`
with something hand-written would lose it.

Copy **both**: `hardware-configuration.nix` is not just tidiness. It carries
`nixpkgs.hostPlatform`, which `flake.nix` relies on because `mkHost` passes no
`system` argument -- without that file the evaluation fails outright.

The one line to delete is `programs.firefox.enable = true;` — Firefox comes from
`system/packages.nix` instead, and `system/nixos.nix` refuses to build while both
are set.

## users.nix

```nix
{
  christianhuth = [ "git" "vscodium" ];
  huthcn = [ "bitwarden" "plex" ];
}
```

Names resolve to `home/features/<name>.nix`. Every user listed here additionally
gets `home/default.nix`, the shared base, and a system-level identity from
`users/<name>.nix` -- uid, gid and group membership, which are the same on every
machine. `root` is added automatically and always gets `home/root.nix` only.

This file is the whole point of the layout: the same user can carry a different
feature set on a different machine.
