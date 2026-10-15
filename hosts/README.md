# hosts/

One directory per NixOS machine, named after its hostname. `flake.nix` turns
every directory here into `nixosConfigurations.<name>`, so on that machine

```bash
sudo nixos-rebuild switch --flake .
```

picks the right one by hostname, without `#<name>`.

Each directory holds the two files the installer wrote to `/etc/nixos`,
copied verbatim:

| File                         | What it carries                                                        |
| ---------------------------- | ---------------------------------------------------------------------- |
| `hardware-configuration.nix` | file systems, the root LUKS device, kernel modules for this hardware   |
| `configuration.nix`          | boot loader, **the swap LUKS device**, hostname, locale, keymap, desktop, the user account, `system.stateVersion` |

Keep both as they are. In particular, the installer puts the encrypted
**swap** device into `configuration.nix`, not into
`hardware-configuration.nix` (`nixos-generate-config` does not detect it), so
replacing `configuration.nix` with something hand-written would lose it.

The one line to delete is `programs.firefox.enable = true;` — Firefox comes
from `system/packages.nix` instead, and `system/nixos.nix` refuses to build
while both are set.

Everything shared between machines lives in `system/nixos.nix` and `home/`,
not here.
