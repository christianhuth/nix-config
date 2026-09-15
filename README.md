# nix-config

Nix configuration for `christianhuth` on **Ubuntu 26.04** (not NixOS).

## The two layers

The key point: **real, declarative "system-wide" only exists on NixOS.** On
Ubuntu, Nix is "just" a package manager alongside apt — there is no
`environment.systemPackages`, because nothing evaluates NixOS modules for the
system. Hence two separate paths:

|              | Layer 1: system-wide                            | Layer 2: user                   |
| ------------ | ----------------------------------------------- | ------------------------------- |
| Defined in   | `system/packages.nix`                           | `home/`                         |
| Mechanism    | `nix profile` → `/nix/var/nix/profiles/default` | Home Manager → `~/.nix-profile` |
| Applies to   | all users                                       | `christianhuth` only            |
| Run as       | `root` (`sudo`)                                 | normal user                     |
| Declarative? | package list yes, applying it is manual         | fully                           |

Layer 1 is deliberately built so it **moves to NixOS 1:1** later: the list in
`system/packages.nix` simply becomes the contents of
`environment.systemPackages`. `home/` stays completely unchanged on migration.

## Repository layout

| File                  | What it defines                                                       | Applies to      |
| --------------------- | --------------------------------------------------------------------- | --------------- |
| `flake.nix`           | inputs (nixpkgs, Home Manager) and both outputs                       | —               |
| `system/packages.nix` | system-wide packages, plus the Firefox pref                           | all users       |
| `home/default.nix`    | **the per-user package list** (`home.packages`) and the imports below | `christianhuth` |
| `home/bash.nix`       | bash, and the generated `~/.bashrc`, `~/.profile`, `~/.bash_profile`  | `christianhuth` |
| `home/git.nix`        | git and its configuration                                             | `christianhuth` |
| `home/kubeswitch.nix` | kubeswitch and its shell function                                     | `christianhuth` |
| `home/krew.nix`       | krew and its plugins                                                  | `christianhuth` |
| `home/vscodium.nix`   | VSCodium and its extensions                                           | `christianhuth` |
| `BOOTSTRAP.md`        | one-time setup of Nix itself                                          | —               |

### Where are the per-user packages?

In **`home/default.nix`**, but they arrive there in two different ways — which 
is why not everything shows up in one list:

1. **`home.packages`** — the plain list at the bottom of `home/default.nix`.
   This is where most tools live: `kubectl`, `k9s`, `gh`, `signal-desktop` and
   so on. Add a tool here when it needs no further configuration.
2. **The imported modules.** `programs.git.enable` and
   `programs.vscodium.enable` install their package *as a side effect* of being
   enabled, and `home/krew.nix` adds `krew` through its own `home.packages`.
   That is why git, VSCodium and krew do **not** appear in the main list.

Rule of thumb: if you only want the binary, put it in `home.packages`. If you
also want to manage its configuration, give it its own module and let
`programs.<name>` install it.

The chain from the flake is:

```
flake.nix
  └─ homeConfigurations."christianhuth"
       └─ modules = [ ./home/default.nix ]
            ├─ home.packages = [ ... ]   <-- the main list
            ├─ ./git.nix
            ├─ ./vscodium.nix
            └─ ./krew.nix
```

## Not just packages: configuration

Nix can set program settings declaratively too. The same split applies as with
packages — and the mechanism you pick decides whether a setting applies to
everyone or to a single user.

**git** (`home/git.nix`, per-user). `programs.git.settings` writes
`~/.config/git/config` — the same file `git config --global` touches:

```nix
programs.git.settings.init.defaultBranch = "main";
```

Beyond the identity (`user.name`, `user.email`), which git refuses to commit
without, these are set:

| Setting | Why |
|---|---|
| `push.autoSetupRemote = true` | pushing a new branch no longer needs `--set-upstream` |
| `pull.rebase = true` | no accidental merge commits on pull (opinionated — `pull.ff = "only"` is the stricter alternative) |
| `rebase.autoStash = true` | rebase works with a dirty working tree |
| `fetch.prune = true` | drops local refs to branches deleted on the remote |
| `merge.conflictStyle = "zdiff3"` | conflict markers also show the common ancestor |
| `diff.algorithm = "histogram"` | clearly better diffs than the default Myers |
| `rerere.enabled = true` | remembers conflict resolutions and reapplies them |
| `commit.verbose = true` | shows the full diff while writing the commit message |

Deliberately left out, but worth knowing about:

- **`programs.git.includes`** — conditional configuration. The usual reason is
  a second identity: a different `user.email` below `~/code/work/`, selected by
  `condition = "gitdir:~/code/work/"`.
- **`programs.git.signing`** — `key`, `format` (`ssh`, `openpgp` or `x509`) and
  `signByDefault`. SSH signing is the least effort, since it reuses an existing
  SSH key.
- **`programs.git.ignores`** — a global gitignore. `result`, `result-*` and
  `.direnv` are good candidates on a Nix machine, so they no longer have to go
  into every single repository.
- **`programs.delta.enable`** with `enableGitIntegration = true` — a syntax
  highlighting pager for diffs. Note this is its own Home Manager module; the
  older `programs.git.delta` no longer exists.
- **`programs.gh`** — `gh auth login` also registers git's credential helper,
  which replaces storing a token by hand.

**Firefox** (`system/packages.nix`, system-wide). There are two routes here,
and only one of them reaches all users:

| Route | File | Applies to |
|---|---|---|
| `programs.firefox.profiles.<n>.settings` (Home Manager) | `user.js` in the profile | that one user |
| `firefox.override { extraPrefs = ... }` | `mozilla.cfg` in the package | **all users** |

Since Firefox lives in layer 1 here, we take the second route — the setting
becomes part of the package:

```nix
(firefox.override {
  extraPrefs = ''
    defaultPref("identity.sync.tokenserver.uri", "https://firefox.knell.it/token/1.0/sync/1.5");
  '';
})
```

`defaultPref()` replaces the built-in default but leaves the value editable in
`about:config`. `lockPref()` makes it immutable.

To verify after switching, open `about:config` and search for the pref — it
should show your URL, marked as "default" rather than "modified".

Note that the Home Manager route would not have worked here anyway: with
`stateVersion = "26.05"` it writes profiles to `~/.config/mozilla/firefox`, and
that XDG path only takes effect when Home Manager builds the Firefox package
itself (it passes the path to the nixpkgs wrapper, which sets `MOZ_APP_DATA`).
A Firefox from layer 1 is not wrapped by Home Manager and keeps reading
`~/.mozilla/firefox`, so the `user.js` would be ignored without any error.

**The shell** (`home/bash.nix`, per-user). `programs.bash.enable` makes Home
Manager generate `~/.bashrc`, `~/.profile` and `~/.bash_profile` — it owns
those files outright. That is the intended end state for a declarative setup,
but it does replace Ubuntu's `/etc/skel` defaults, so the parts worth keeping
are ported explicitly: the coloured prompt, `dircolors` plus the `ls`/`grep`
colour aliases, `ll`/`la`/`l`, lesspipe, `checkwinsize`, and the `~/.local/bin`
and `~/bin` PATH entries that Ubuntu's `~/.profile` added.

Deliberately not ported: the `debian_chroot` prompt prefix (there is no
`/etc/debian_chroot` here, so it always expanded to nothing), the Ubuntu
`alert` alias, and the `~/.bash_aliases` include — aliases belong in
`programs.bash.shellAliases` now.

One thing Home Manager cannot do off NixOS is change your login shell: the
entry in `/etc/passwd` stays Ubuntu's `/bin/bash`. It does not need to change,
since that bash reads the generated files just the same.

## Applying

Prerequisite: Nix is installed and flakes are enabled — see
[BOOTSTRAP.md](BOOTSTRAP.md).

```bash
cd ~/code/christianhuth/nix-config

# Layer 1 -- system-wide, install once.
# The absolute path is required: sudo's secure_path does not contain the Nix
# profile, so plain `sudo nix` fails with "command not found". See Pitfalls.
sudo /nix/var/nix/profiles/default/bin/nix profile add .#system-packages

# Layer 2 -- user. Use -b backup the VERY FIRST time so existing files are
# moved aside instead of reported as a conflict:
nix run home-manager/release-26.05 -- switch -b backup --flake .#christianhuth

# from then on:
home-manager switch --flake .#christianhuth
```

Then **log out and back in once** so GNOME re-reads `XDG_DATA_DIRS` and
Spotify, Firefox and friends appear in the application menu.

### Updating

```bash
nix flake update                            # re-pin inputs (flake.lock)
sudo /nix/var/nix/profiles/default/bin/nix profile upgrade --all   # layer 1
home-manager switch --flake .#christianhuth # layer 2
```

### Rolling back

```bash
home-manager generations              # list them
/nix/store/...-home-manager-generation/activate   # activate the one you want
sudo /nix/var/nix/profiles/default/bin/nix profile rollback   # layer 1
```

## Pitfalls

**`sudo: 'nix': command not found`.** Nix is installed just fine — this is
sudo, not Nix. Ubuntu's sudoers sets `secure_path`, which replaces `PATH` for
sudo commands and does not contain `/nix/var/nix/profiles/default/bin`. The
`/etc/profile.d/nix.sh` that puts Nix on your PATH only applies to your own
login shell. Two ways out:

```bash
# per command -- what this README uses
sudo /nix/var/nix/profiles/default/bin/nix profile add .#system-packages

# or permanently: append to secure_path
sudo visudo   # ...:/snap/bin:/nix/var/nix/profiles/default/bin
```

Installing as root lands in `/nix/var/nix/profiles/per-user/root/profile`,
which is exactly what `/nix/var/nix/profiles/default` symlinks to — so this is
the system-wide profile, as intended.

**`warning: Git tree ... is dirty`.** Informational, not an error. Nix says the
flake source is not a clean git checkout, so the result cannot be traced back
to a commit. Staged-but-uncommitted files count as dirty. It disappears once
you commit — and `flake.lock` belongs in that commit.

**`git init` and flakes.** Inside a git repository, flakes only see **files git
knows about**. So after `git init`, always run `git add .` — otherwise
evaluation fails with "file not found" for files that are plainly there. The
most common beginner trap.

**Collisions in layer 1.** `buildEnv` aborts when two packages ship the same
file (`collision between ...`). If that happens, add this to
`system/packages.nix`:

```nix
ignoreCollisions = true;
```

**Applications missing from the menu.** Log out and back in. `XDG_DATA_DIRS`
has to contain the profiles' `share` directories, and the desktop session only
picks that up at login.

Checking it in a terminal is misleading — your shell gets the variable from
`~/.profile`, but the GNOME session does not read that file on Wayland. Check
the session itself instead:

```bash
tr '\0' '\n' < /proc/$(pgrep -x gnome-shell | head -1)/environ | grep XDG_DATA_DIRS
```

The mechanism that feeds the Wayland session is
`~/.config/environment.d/10-home-manager.conf`, written by
`targets.genericLinux.enable`. It covers both the system profile
(`/nix/var/nix/profiles/default/share`) and the user profile
(`~/.nix-profile/share`).

**`kubectl <plugin>` finds nothing.** Check that `~/.krew/bin` is on your PATH.
It gets there via `home.sessionPath`, which Home Manager writes into
`hm-session-vars.sh` and sources from the `~/.profile` it generates — so a
shell started before the first switch will not have it. Open a new terminal.

**`switch` is not a command.** Same cause: the kubeswitch shell function is
injected into the generated `~/.bashrc`, so it only exists in shells started
after the switch. Note that calling the `switcher` binary directly does not
work by design — see the kubeswitch note below.

## Deviations from the original wish list

All attribute names were verified against nixpkgs `nixos-26.05`. Five of them
are not what you would expect:

| Wanted | Used | Why |
|---|---|---|
| `helm` | **`kubernetes-helm`** | in nixpkgs, `helm` is a polyphonic synthesizer, not Kubernetes |
| Microsoft Teams | **`teams-for-linux`** | `teams` exists in nixpkgs for macOS only; Microsoft discontinued the official Linux client |
| `virtctl` | **`kubevirt`** | no package of its own; `virtctl` ships as part of `kubevirt` |
| `composer` | **`php84Packages.composer`** | there is no top-level attribute |
| Nextcloud | **`nextcloud-client`** | listed as "system-wide", read here as the desktop sync client rather than the server. If you meant the server: that does not run sensibly through Nix on Ubuntu, it is a NixOS module (`services.nextcloud`). |

Also worth knowing:

- **`wireguard-tools`** sits with the user, as requested. It provides `wg` and
  `wg-quick` — bringing tunnels up still needs `sudo`, and there are no systemd
  units for tunnels here (that would be `networking.wireguard.interfaces` on
  NixOS).
- **Spotify** is unfree, hence `config.allowUnfree = true` in the flake. Because
  it is wired in there, you do not need `NIXPKGS_ALLOW_UNFREE=1` when
  installing.
- **Both VSCodium extensions are available in nixpkgs**
  (`ms-kubernetes-tools.vscode-kubernetes-tools` and `anthropic.claude-code`),
  so no marketplace overlay such as `nix-vscode-extensions` is needed.

## krew

`home/krew.nix` is the **only non-declarative part** of this configuration.
krew fetches plugins from its own index at runtime, which Nix cannot reproduce
deterministically. The activation script is idempotent (it checks
`~/.krew/receipts/*.yaml`) and will not abort the switch while you are offline.

Note that the nixpkgs package only ships `bin/krew`. `krew install foo`
followed by `kubectl foo` works; `kubectl krew ...` does not, because there is
no `kubectl-krew` on PATH. Use `krew ...` directly instead.

11 of the 18 plugins also exist natively in nixpkgs — there they would be fully
reproducible and pinned by `flake.lock`:

| krew plugin | nixpkgs |
|---|---|
| access-matrix | `rakkess` |
| deprecations | `kubepug` |
| df-pv | `kubectl-df-pv` |
| explore | `kubectl-explore` |
| oidc-login | `kubelogin-oidc` |
| resource-capacity | `kube-capacity` |
| stern | `stern` |
| tail | `kubetail` |
| tree | `kubectl-tree` |
| view-secret | `kubectl-view-secret` |
| virt | `kubevirt` (already included) |
| get-all, rbac-lookup, rbac-view, rolesum, topology, who-can, whoami | — not in nixpkgs |

Because the remaining 7 are missing, everything goes through krew here — one
source instead of two. If reproducibility matters more to you than
completeness, move the left column into `home/default.nix` and shorten the list
in `krew.nix`.

## kubeswitch

`pkgs.kubeswitch` ships a single binary, `switcher`, and upstream is explicit
that it must not be called directly: the actual command is a shell function,
because changing `KUBECONFIG` in the current shell cannot be done by a child
process.

`programs.kubeswitch` in `home/kubeswitch.nix` handles that — it installs the
package, generates the shell function and its completions, and injects them
into `programs.bash`. That dependency is the reason `home/bash.nix` has to be
enabled for it to work.

Two things worth knowing:

- The module names the function **`kswitch`** by default. It is set to `switch`
  here so upstream's documentation matches what you type.
- `programs.kubeswitch.settings` is written to `~/.kube/switch-config.yaml` and
  is where kubeconfig stores are configured (filesystem paths, Gardener, Cluster
  API, Vault and so on). It is left empty for now, so kubeswitch uses its
  defaults.

## Can Nix manage users?

**On NixOS: yes, completely.** Users, groups, shell, SSH keys, even the
password hash are ordinary configuration:

```nix
users.mutableUsers = false;              # only what is written here exists
users.users.christianhuth = {
  isNormalUser = true;
  description  = "Christian Huth";
  extraGroups  = [ "wheel" "docker" "networkmanager" ];
  shell        = pkgs.zsh;
  openssh.authorizedKeys.keys = [ "ssh-ed25519 AAAA..." ];
  hashedPassword = "$6$...";

  # Packages for THIS user only, without Home Manager:
  packages = with pkgs; [ k9s kubectl ];
};
```

That removes `useradd` entirely — `nixos-rebuild switch` creates the user, and
deleting them from the file removes them again.

**On Ubuntu: no.** Creating users stays Ubuntu's job (`adduser`). Nix can only
supply packages here. What you do already have is the **per-user package
assignment** — exactly the split described above — and Home Manager scales to
several users:

```nix
homeConfigurations."christianhuth" = ... modules = [ ./home/default.nix ];
homeConfigurations."someoneelse"   = ... modules = [ ./home/someoneelse.nix ];
```

Each user then runs their own `home-manager switch --flake .#<name>`. Shared
parts go into modules that both configurations import.

## Path to NixOS

Migrating later changes surprisingly little:

1. `home/` stays **unchanged** and gets wired in as a NixOS module
   (`home-manager.nixosModules.home-manager`) — or stays standalone.
2. `system/packages.nix` becomes `environment.systemPackages`.
3. New additions are `hosts/<hostname>/` with `configuration.nix` and
   `hardware-configuration.nix`, plus `nixosConfigurations.<hostname>` in the
   flake.
4. Only then do user management, systemd services, bootloader, kernel modules
   and so on come into play — that is the actual payoff of NixOS.
