# home/features/

One Home Manager module per feature, named after the feature. A host selects
them by name in `hosts/<hostname>/users.nix`:

```nix
{
  christianhuth = [ "git" "vscodium" ];
}
```

which `flake.nix` resolves to `home/features/git.nix` and
`home/features/vscodium.nix`. Everything a user gets regardless of machine lives
in `home/default.nix` instead, which every user imports.

A feature that needs another one imports it itself:

```nix
{
  imports = [ ./gnupg.nix ];   # git's credential helper is pass-git-helper
}
```

The module system deduplicates imports by file path, so two features depending on
the same third one is fine. Doing it this way rather than relying on the host list
means a feature can never land half-configured.

The split out of `home/default.nix` happens one module at a time, each step
verified to leave the result byte-identical:

```bash
nix eval --raw .#nixosConfigurations.<host>.config.home-manager.users.<user>.home.activationPackage.drvPath
```

Known dependencies to respect when moving things here:

| Module | Needs |
| ------------- | ------------------------------------------------- |
| `git` | `gnupg` (reads `config.programs.gpg`) |
| `code` | `git` (reads `config.programs.git`) |
| `containerlab` | `vscodium` (writes `programs.vscodium.profiles…`) |
| `atuin`, `direnv`, `kubeswitch`, `starship` | `bash` (shell integration) |
