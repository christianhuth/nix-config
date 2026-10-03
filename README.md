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
| `home/atuin.nix`      | atuin shell history, local only                                       | `christianhuth` |
| `home/bash.nix`       | bash, and the generated `~/.bashrc`, `~/.profile`, `~/.bash_profile`  | `christianhuth` |
| `home/code.nix`       | ~/code directory layout + the managed ansible .envrc                  | `christianhuth` |
| `home/ddev.nix`       | ddev + mkcert, and the Docker prerequisite apt has to cover           | `christianhuth` |
| `home/devenv.nix`     | devenv, and why it stays out of direnv lib/                           | `christianhuth` |
| `home/direnv.nix`     | direnv + nix-direnv                                                   | `christianhuth` |
| `home/fonts.nix`      | fontconfig for the Nix profile + the Nerd Font starship needs         | `christianhuth` |
| `home/git.nix`        | git and its configuration                                             | `christianhuth` |
| `home/gnupg.nix`      | pass, gnupg, and the GPG_TTY export                                   | `christianhuth` |
| `home/kubeswitch.nix` | kubeswitch and its shell function                                     | `christianhuth` |
| `home/root.nix`       | entry point for the root user: shell + prompt only                    | `root`          |
| `home/starship.nix`   | the shell prompt (owns PS1; see home/bash.nix)                        | `christianhuth` |
| `home/wireguard.nix`  | wireguard-tools + import of ~/.wireguard/*.conf into NetworkManager   | `christianhuth` |
| `home/yubikey.nix`    | ykman, plus what Ubuntu has to provide around it                      | `christianhuth` |
| `home/krew.nix`       | krew and its plugins                                                  | `christianhuth` |
| `home/vscodium.nix`   | VSCodium and its extensions                                           | `christianhuth` |
| `pkgs/overlay.nix`    | our own packages and overrides, applied on top of nixpkgs             | both layers     |
| `pkgs/termius/…`      | Termius built from the vendor's official `.deb`                       | `christianhuth` |
| `system/apparmor/…`   | AppArmor profiles granting `userns` (see “Electron on Ubuntu”)        | all users       |
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
| `pull.rebase = false` | kept from the previous machine's setting; `true` (rebase on pull) or `pull.ff = "only"` are the alternatives |
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

**Settings from `home/git.nix` not taking effect.** git reads both
`~/.config/git/config` (which Home Manager writes) and `~/.gitconfig`, and
`~/.gitconfig` wins for single-valued variables. Anything ever set with
`git config --global` before Home Manager took over lives there and silently
overrides this configuration. Check with:

```bash
git config --list --show-origin | grep gitconfig
```

There is currently one such leftover, `init.defaultBranch = main` — the same
value this repository sets, so harmless today. Removing it avoids the trap:

```bash
rm ~/.gitconfig
```

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

**`MESA-LOADER: failed to open dri: /run/opengl-driver/lib/...`.** Nix-built
graphics applications look for GPU drivers under `/run/opengl-driver`, a path
that only exists on NixOS. Without it Mesa falls back to software rendering, so
this affects every GUI app here, not just one.

`targets.genericLinux.gpu` is already enabled (it defaults to on whenever
`targets.genericLinux.enable` is set), and it puts a helper in the profile. Home
Manager cannot write to `/etc` off NixOS, so run it once as root:

```bash
sudo ~/.nix-profile/bin/non-nixos-gpu-setup
```

It installs `/etc/tmpfiles.d/non-nixos-gpu.conf`, which symlinks
`/run/opengl-driver` at the host's GPU libraries, and registers a GC root. Re-run
it after an update that rebuilds the helper.

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
| `ansible-core` | **`ansible`** | reversed from what it looks like: `pkgs.ansible` *is* ansible-core (2.21.1); there is no top-level `pkgs.ansible-core`, and the full bundle with collections is `python3Packages.ansible` (13.7.0) |
| Nextcloud | **`nextcloud-client`** | listed as "system-wide", read here as the desktop sync client rather than the server. If you meant the server: that does not run sensibly through Nix on Ubuntu, it is a NixOS module (`services.nextcloud`). |

Also worth knowing:

- **`wireguard-tools`** sits with the user, as requested. It provides `wg` and
  `wg-quick` — bringing tunnels up still needs `sudo`, and there are no systemd
  units for tunnels here (that would be `networking.wireguard.interfaces` on
  NixOS).
- **Spotify** is unfree, hence `config.allowUnfree = true` in the flake. Because
  it is wired in there, you do not need `NIXPKGS_ALLOW_UNFREE=1` when
  installing.
- **VSCodium extensions do not come from nixpkgs** — see the section below for
  why not.

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

### kubectx / kubens, and why they alias the function

```nix
programs.bash.shellAliases = {
  kubectx = "switch";
  kubens = "switch namespace";
};
```

Both point at the shell function, never at the `switcher` binary — and that is
the whole difference between working and not working. The generated init script
makes it explicit:

```bash
function switch(){
  RESPONSE="$($EXECUTABLE_PATH "${opts[@]}")"   # runs the switcher binary
  ...                                           # response: "__ <path>,<context>"
  export KUBECONFIG="$KUBECONFIG_PATH"          # <- this is what sets it
}
```

The binary only *prints* the selected kubeconfig path on stdout; a child process
cannot change its parent shell's environment. So calling `switcher` directly
selects a cluster and leaves `KUBECONFIG` unset, after which kubectl falls back
to no configuration at all:

```
The connection to the server localhost:8080 was refused
```

That is exactly the failure upstream means when it says not to call the binary
directly. Use `switch` (or now `kubectx`), and `kubens` for the namespace.

## Own packages: Termius from the official .deb

`pkgs.termius` in nixpkgs does not build Termius from source — it repackages
the **Snap Store** artifact, downloading a `.snap` from `api.snapcraft.io` and
running `unsquashfs` on it. The revision pinned in nixpkgs 26.05 is 9.36.2,
several releases behind, so using it would have meant a downgrade.

Termius does publish an official `.deb`, so `pkgs/termius/package.nix` builds
from that instead and `pkgs/overlay.nix` substitutes it for the nixpkgs
package. Everything else keeps referring to plain `termius`.

| Source | Version |
|---|---|
| nixpkgs 26.05 (snap-based) | 9.36.2 |
| Snap Store | 9.43.1 |
| official `.deb` — what we build | **10.1.0** |

The `.deb` is unpacked with `dpkg-deb -x`; `autoPatchelfHook` then rewrites the
interpreter and RPATHs of its 24 bundled ELF files. `buildInputs` is exactly
the set of external `DT_NEEDED` entries those files carry, minus what stdenv
already provides. `wrapGAppsHook3` supplies the GSettings schemas, the
GDK-Pixbuf loader cache and dconf that any GTK application needs.

### Making it start on Ubuntu

Termius needs the two root steps that apply to every Electron app here — the
AppArmor profile from **Electron applications on Ubuntu** below, plus the GPU
setup from the `MESA-LOADER` entry under Pitfalls. Without the profile it aborts
at startup:

```
FATAL:sandbox/linux/suid/client/setuid_sandbox_host.cc:166] The SUID sandbox
helper binary was found, but is not configured correctly.
```

Termius gets its own profile (`system/apparmor/termius`) rather than being
covered by the shared one, because the vendor `.deb` bundles its own Electron at
`opt/Termius/termius-app` instead of using nixpkgs'.

The alternative would be adding `--no-sandbox` to the wrapper in
`pkgs/termius/package.nix`. That needs no root but switches off a real security
boundary in a program holding SSH credentials, so the profile is the better
trade.

### Updating it

This is the price of leaving nixpkgs: **no automatic updates.** Termius ships an
electron-updater manifest that hands over both values needed:

```bash
curl -s https://autoupdate.termius.com/linux/latest-linux.yml
```

```yaml
version: 10.1.0
path: termius-app_10.1.0_amd64.deb
sha512: mABJip003+zApFtqczR0f+IcF85vLMqWzqnQeoiZEXVGtjkM1MsH+kvLYXEn09XiBAseFiyQyUW8AI/b607wQQ==
```

That `sha512` is base64-encoded, which is exactly Nix's SRI format — prefix it
with `sha512-` and it goes straight into the derivation. So an update means:
copy `version` and the prefixed hash into `pkgs/termius/package.nix`, then

```bash
nix build .#termius && ./result/bin/termius-app
```

`termius` is exposed as a flake output for that purpose.

## pass and GnuPG

Both are plain entries in `home.packages`, but two choices in there are
deliberate.

**`pass-wayland` instead of `pass`.** It is the same 1.7.4, defined as
`pass.override { waylandSupport = true; }`. Since that override only *adds*
Wayland support and leaves `x11Support` at its default, `pass -c` copies through
`wl-copy` in the Wayland session and still works for XWayland applications.
Plain `pass` would only have shipped `xclip`.

**gnupg coexists with Ubuntu's.** Ubuntu has gnupg 2.4.8 in `/usr/bin`; this is
2.4.9, and because `~/.nix-profile/bin` comes first in PATH it shadows Ubuntu's
`gpg`. Verified to work: it reads the existing `~/.gnupg` keyring, trust
included. But it prints this on every invocation:

```
gpg: WARNING: server 'gpg-agent' is older than us (2.4.8 < 2.4.9)
```

The cause is that the *client* now comes from Nix while the *agent* is still
Ubuntu's, started by its systemd user units (`gpg-agent.socket` is active, and
the process runs as `gpg-agent --supervised`). Harmless, just noisy.

The clean fix is to let Home Manager own the agent too, via
`services.gpg-agent`. That writes `~/.config/systemd/user/gpg-agent.*`, which
takes precedence over Ubuntu's units, so it is a takeover rather than a
conflict. It also settles pinentry: nixpkgs builds gnupg with
`guiSupport = false` on Linux, so no pinentry path is compiled in and the agent
falls back to whatever `pinentry` is in PATH — currently Ubuntu's
`/usr/bin/pinentry`.

This is deliberately *not* configured yet. The existing key belongs to a work
identity, and taking over the agent touches passphrase caching and possibly SSH
agent behaviour, so it should be a conscious step rather than a side effect of
installing a package.

### The agent, GPG_TTY and pinentry

`services.gpg-agent` in `home/gnupg.nix` takes the agent over from Ubuntu. Home
Manager writes `~/.config/systemd/user/gpg-agent.{socket,service}`, and user
units there take precedence over Ubuntu's in `/usr/lib/systemd/user`, so this is
a handover rather than a fight. It also removes the warning above, because
client and agent now come from the same build.

Three things come with it:

**`GPG_TTY`.** `enableBashIntegration = true` emits exactly

```bash
GPG_TTY="$(tty)"
export GPG_TTY
```

into the interactive section of the generated `~/.bashrc`. `pass` and
`pass-git-helper` need it so pinentry knows which terminal to prompt on.

The placement matters. `home.sessionVariables` and
`programs.bash.sessionVariables` look like the right options and are not: both
land in `~/.profile`, which is sourced **once** per login session, whereas
`$(tty)` has to be evaluated per terminal — and in a non-interactive context
`tty` prints "not a tty" and exits non-zero, which would make the variable
actively wrong. The shell integration writes it after the interactive guard,
where a tty is guaranteed:

```bash
[[ $- == *i* ]] || return     # interactive guard
...
GPG_TTY="$(tty)"              # <- here
export GPG_TTY
```

Setting it by hand through `programs.bash.initExtra` works identically — that
option is of type `lines` and merges — but there is no reason to once the agent
module is on.

**pinentry.** nixpkgs builds gnupg with `guiSupport = false` on Linux, so no
pinentry path is compiled in and the agent falls back to whatever `pinentry` is
in PATH. `pinentry.package` pins it instead, which produces

```
# ~/.gnupg/gpg-agent.conf
grab
pinentry-program /nix/store/…-pinentry-gnome3-1.3.2/bin/pinentry
```

`pinentry-gnome3` suits this GNOME/Wayland session. If a prompt ever fails to
appear, adding `pkgs.gcr` to `home.packages` is the documented fix and
`pkgs.pinentry-curses` the fallback.

**`gpg.conf`.** `programs.gpg.enable` also writes `~/.gnupg/gpg.conf` with Home
Manager's hardening defaults (AES256, SHA512 preferences, `keyid-format
0xlong`, …). There was no `gpg.conf` here before, so nothing was overwritten,
and `mutableKeys`/`mutableTrust` stay at their default `true` — the existing
keyring, secret keys and trustdb are untouched.

Not enabled: `enableSshSupport`. That would make gpg-agent replace ssh-agent and
take over SSH key handling, which is a separate decision from managing GnuPG.

### git credentials via pass

`home/git.nix` sets

```nix
credential.helper = "!pass-git-helper $@";
```

The leading `!` tells git to run the value as a shell command. Verified to round
trip correctly through git's own config parser:

```bash
$ git config --get credential.helper
!pass-git-helper $@
```

`pass-git-helper` itself is installed in `home/gnupg.nix`, since a helper
configured but not installed would only surface as a credential failure.

One manual step is left, and it cannot sensibly be generated: the helper needs a
host-to-entry mapping at `~/.config/pass-git-helper/git-pass-mapping.ini`, whose
content depends on how the password store is laid out. For example:

```ini
[github.com*]
target=github.com

[gitlab.example.org*]
target=work/gitlab
```

Once that layout is settled, the file can be moved into the configuration as an
`xdg.configFile` entry.

### Two credential backends side by side

GitHub is handled by `gh`, not by pass, because gh manages and refreshes its own
OAuth token. That needs a reset, because git *accumulates* `credential.helper`
values rather than replacing them:

```nix
credential."https://github.com".helper = [
  ""                                        # clears the inherited list
  "!${lib.getExe pkgs.gh} auth git-credential"
];
```

Without the empty first element, pass-git-helper would still be asked for
github.com first. Verified with `GIT_TRACE=1`:

```
# host=github.com
run_command: '…/gh auth git-credential get'          <- only gh

# host=gitlab.proact.eu
run_command: 'pass-git-helper $@ get'                 <- only pass
```

Note `lib.getExe pkgs.gh` rather than a literal path. The previous machine had
`/usr/bin/gh` hardcoded, which does not exist here at all since gh comes from
Nix — that configuration would have failed silently.

`gh` still needs `gh auth login` once; the helper cannot invent a token.

### Per-directory identity

The old `[includeIf "gitdir:~/code/proact/"] path = ~/.gitconfig-proact` became:

```nix
includes = [
  {
    condition = "gitdir:~/code/proact/";
    contents.user = {
      name = "Christian Huth";
      email = "christian.huth@proact.eu";
    };
  }
];
```

Using `contents` instead of `path` keeps the work identity in this repository:
Home Manager generates the included file into the store and points `includeIf`
at it, so there is no separate `~/.gitconfig-proact` to keep in sync.

### Why the username had to be configured

On the previous machine pass-git-helper returned only a password and that was
enough, because the username was baked into the remote URL:

```
remote.origin.url  https://christian.huth@gitlab.proact.eu/paas/pass
```

git takes the username from there and asks the helper only for the password. The
prompt therefore only appears when cloning a URL *without* a username — which
is when it was noticed. `username_extractor = "static"` in the pass-git-helper
mapping closes that gap, so both URL forms work.

### Initialising the store

`pass` needs a GPG key with an encryption subkey. The existing key qualifies:

```
sec   rsa4096/175F8A4C86918611  Christian Huth (dechhu) <christian.huth@proact.eu>
ssb   rsa4096/21AE42C0E58533ED  [E]     <- encryption subkey
```

```bash
pass init 175F8A4C86918611
```

That creates `~/.password-store`. Name the primary key; pass resolves the
encryption subkey itself.

Worth knowing for later: `programs.password-store` is a Home Manager module for
declarative settings such as `PASSWORD_STORE_DIR`, and extensions live under
`passExtensions` (`pass-otp`, `pass-import`, …), added through
`pass.withExtensions`.

## The ~/code layout

`home/code.nix` keeps three directories present and manages one `.envrc`:

```
~/code/proact/ansible        <- plus its .envrc
~/code/typo3/extensions
~/code/typo3/sitepackages
```

Directory creation is an activation script rather than `home.file`, because
`home.file` cannot express "an empty *mutable* directory" — it would need a
placeholder file in each one, or turn them into store symlinks. These have to
stay ordinary writable directories: they hold working copies.

### Can Nix clone repositories?

Not usefully, and it is worth being precise about why. `fetchgit` and friends do
fetch repositories, but into `/nix/store` — read-only, and with no `.git` you
could commit to. That is right for build inputs and wrong for a working copy.

What does work is the same pattern as `home/wireguard.nix`: an idempotent
activation script that clones a repository *if the directory does not exist yet*.
Nix then declares **which** repositories belong where, while git does the
cloning. Deliberately clone-only, not pull: re-pulling on every switch would
trample dirty working trees and half-finished branches.

If more than bootstrapping is wanted, nixpkgs has purpose-built multi-repo tools
— `mr` (myrepos), `vcspull`, `gita` — which handle status and updates across many
checkouts. Those are the right answer for "keep 20 repositories in sync"; an
activation script is the right answer for "make sure this one is there".

`home/code.nix` does exactly that. Three repositories are declared:

| Path below `~/code` | Repository |
|---|---|
| `proact/ansible/base` | `devops/pmcp-base.git` |
| `proact/ansible/operational-docs` | `devops/operational-docs.git` |
| `proact/ansible/site` | `devops/pmcp-site.git` |

All three take the remote's default branch. `branch` is an optional per-repository
attribute for the case where a specific one is needed:

```nix
"proact/ansible/base" = {
  url = "https://forgejo.160f93e3-44a9-4676-bb3c-f98a216e1918.pmcp.proact.eu/devops/pmcp-base.git";
  branch = "stable-20260626";
};
```

Note this only affects *new* clones. The existing `base` working copy sits on
`stable-20260626` and stays there — the script never touches a directory that
already exists, so it neither pulls nor switches branches.

The URLs deliberately drop the `christian.huth@` that the existing remotes carry.
That username was only ever there to work around a credential helper that did not
return one; `username_extractor = "static"` now supplies it, so embedding it is
redundant. All three carry the `.git` suffix, without which GitLab answers with a
redirect (`warning: redirecting to .../pmcp-base.git/`) — harmless but noisy.

The logic is a `writeShellApplication`, run both from `home.activation` and as the
command `code-repos-clone`, so a newly declared repository can be fetched without
a full switch. It exports `GIT_TERMINAL_PROMPT=0` on purpose: credentials come
from pass-git-helper via gpg-agent, and if that chain is not ready — a fresh
machine, a locked agent — the clone should fail visibly rather than hang inside
`home-manager switch`. A failure prints what to re-run and does not abort the
activation.

Verified end to end by cloning `pmcp-base` into a temporary directory: credentials
resolved with no prompt, and `--branch` checked out the requested branch.

### The managed .envrc

Taken over verbatim from the existing local file. It is safe to keep here because
it contains no secret itself — it *fetches* one via
`pass show proact/ssh-password`:

```bash
layout_python3

export ANSIBLE_BECOME_PASS=$(pass show proact/ssh-password | head -n 1)
export ANSIBLE_VAULT_PASSWORD=$(pwd)/operational-docs/scripts/ansible-vault-password.sh
```

Verified byte-identical to what was there before.

`force = true` is set on that file, and the reason is subtler than it looks.
Home Manager's link helper contains this:

```bash
if [[ -e "$targetPath" && ! -L "$targetPath" ]] && cmp -s "$sourcePath" "$targetPath" ; then
  # The target exists but is identical - don't do anything.
```

So while the content matches, the existing plain file is left alone and *not*
replaced by a symlink — independently of `force`, and reported only in verbose
mode. `force` acts on the earlier `checkLinkTargets` step instead: without it,
the first content change here would abort the switch with "would be clobbered".
With it, the change simply replaces the file with a symlink. Verified by
temporarily altering the content and watching `ln -Tsf` appear in a dry run.

Two consequences to keep in mind: once it is a symlink the file is read-only, so
edits happen in this repository followed by a switch; and direnv records an
allow-token per content, so a change needs `direnv allow` once more.

One correction against the original file: it exported `ANSIBLE_VAULT_PASSWORD`
pointing at a script path, but that variable is the password *itself* in the
versions that support it. The variable for a password file is
`ANSIBLE_VAULT_PASSWORD_FILE`, which is what is used here.

## VSCodium extensions

They come from the `nix-vscode-extensions` flake, not `pkgs.vscode-extensions`,
and the extensions directory is immutable. Both parts are needed; either alone
does not hold.

### What went wrong first

The first attempt declared the extensions from nixpkgs and left
`mutableExtensionsDir` at its default. After a while only GitLens was active, and
Kubernetes Tools had vanished. The symlinks were all still intact — the answer was
in `~/.vscode-oss/extensions/.obsolete`:

```json
{ "anthropic.claude-code-2.1.223": true,
  "ms-kubernetes-tools.vscode-kubernetes-tools-1.3.29": true,
  "eamodio.gitlens-17.11.1": true }
```

**VSCodium had marked every Nix-provided extension obsolete.** Its own
`extensions.json` listed newer marketplace builds as real directories instead.

That is `mutableExtensionsDir` doing exactly what it says: "whether extensions can
be installed or updated manually or by VSCodium". Its default is true whenever only
the `default` profile is used. VSCodium found newer versions, and since
`/nix/store` is read-only it could not update in place — so it installed parallel
copies and retired the Nix ones. The extension with no marketplace replacement
simply disappeared.

### Why the source had to change too

Setting `mutableExtensionsDir = false` stops the drift, but on its own it would
have pinned versions that were badly behind:

| Extension | nixpkgs 26.05 | nixpkgs unstable | upstream |
|---|---|---|---|
| gitlens | 17.11.1 | 17.11.1 | **19.2.0** |
| claude-code | 2.1.223 | 2.1.283 | 2.1.284 |
| kubernetes-tools | 1.3.29 | 1.4.0 | 1.4.1 |

Two major versions behind on gitlens is what made VSCodium overrule the
declaration in the first place. `nix-vscode-extensions` mirrors Open VSX and the
VS Code marketplace daily and closes that gap:

| Extension | now installed |
|---|---|
| `anthropic.claude-code` | 2.1.283 |
| `eamodio.gitlens` | 19.2.0 |
| `ms-kubernetes-tools.vscode-kubernetes-tools` | 1.4.1 |

Two choices inside that flake are deliberate:

**`open-vsx-release`, not `open-vsx`.** The plain set includes pre-releases — for
gitlens that means a date-versioned build (`2026.9.250515`) rather than the 19.2.0
release.

**Open VSX, not `vscode-marketplace`.** The Microsoft marketplace's terms cover
use with Microsoft products, which VSCodium is not. Open VSX carries all three
extensions at the same or newer versions anyway.

**Applied as `nix-vscode-extensions.overlays.default`**, not by reading the flake's
`extensions` output directly. That output is built from the flake's own nixpkgs
instance, which has no `allowUnfree` — and the Claude Code extension is unfree, so
evaluation fails. Going through our `pkgs` fixes it.

### settings.json is managed too

`profiles.default.userSettings` also puts `~/.config/VSCodium/User/settings.json`
under Nix. The reason is narrow: the integrated terminal has its **own** font
setting, entirely separate from Ptyxis, so the starship prompt rendered its
powerline glyphs as boxes there while looking correct in Ptyxis.

```nix
"terminal.integrated.fontFamily" = "'FiraCode Nerd Font Mono', monospace";
```

The five settings that were already in the file are carried over verbatim, and
`enableUpdateCheck`/`enableExtensionUpdateCheck = false` add `update.mode` and
`extensions.autoCheckUpdates` — with an immutable extensions directory there is
nothing VSCodium could do with a discovered update anyway.

**The trade:** the file becomes a read-only store symlink, so VSCodium can no
longer save settings changed through its UI. It had gained an
`explorer.confirmDelete` entry between two looks during this work, so that is a
real change in workflow: new settings go into `home/vscodium.nix` followed by a
switch.

One wrinkle worth recording. Forcing the overwrite has to use the **absolute**
path, because that is the key the module registers the file under:

```nix
home.file."${config.xdg.configHome}/VSCodium/User/settings.json".force = true;
```

The relative `".config/VSCodium/User/settings.json"` form creates a *second*
`home.file` entry aimed at the same target, which Home Manager rejects with
"Conflicting managed target files".

### One-time cleanup

`mutableExtensionsDir = false` replaces the whole `~/.vscode-oss/extensions`
directory with a single store symlink, so the existing directory is in the way:

```
Existing file '/home/christianhuth/.vscode-oss/extensions' would be clobbered
```

Nothing in it is worth keeping — only extension code and VSCodium's own registry.
Settings and state live in `~/.config/VSCodium/User/` (`settings.json`,
`globalStorage`, `workspaceStorage`) and are untouched:

```bash
rm -rf ~/.vscode-oss/extensions
home-manager switch --flake .#christianhuth
```

### The trade

Extensions can no longer be installed from within VSCodium. Adding one means
adding it to `home/vscodium.nix` and switching. `nix flake update` moves the
versions, which for a daily-updating mirror is the point rather than a surprise.

## starship

The prompt, using the bundled **gruvbox-rainbow** preset:

```
with a context     󰕈 christianhuth  …/code/christianhuth/nix-config   master +  ☸ demo-cluster (kube-system)
without            󰕈 christianhuth  …/code/christianhuth/nix-config   master +
```

The preset covers the OS icon, the **username** (it sets
`username.show_always = true` itself) and the path. Three things were needed on
top.

### Kubernetes has to be in the format

starship ships the kubernetes module `disabled = true`, and **no preset turns it
on** — presets only swap symbols and colours. gruvbox-rainbow does not mention
kubernetes at all, so its symbol stays the stock `☸ `.

Enabling it is still not enough: the preset defines its own top-level `format` as
an explicit list of modules, and a module not named there renders nowhere however
it is configured. So the format is overridden:

```nix
format = lib.concatStrings [
  "[](color_orange)" "$os" "$username"
  "[](bg:color_yellow fg:color_orange)" "$directory"
  "[](fg:color_yellow bg:color_aqua)" "$git_branch" "$git_status"
  "[](fg:color_aqua bg:color_purple)" "$kubernetes"        # <- added
  "[](fg:color_purple bg:color_blue)" "$c$cpp$rust…"
  "[](fg:color_blue bg:color_bg3)" "$docker_context" "$conda" "$pixi"
  "[ ](fg:color_bg3)" "$line_break" "$character"
];
```

`color_purple` because the preset leaves purple, green and red unused. The
kubernetes module then follows the preset's own pattern, with `style` carrying only
the background and the foreground set inside `format`:

```nix
kubernetes = {
  disabled = false;
  style = "bg:color_purple";
  format = ''[[ $symbol$context( \($namespace\)) ](fg:color_fg0 bg:color_purple)]($style)'';
};
```

Built with `lib.concatStrings` so each segment sits on its own line and the
separator glyphs stay visible: U+E0B6 opening, U+E0B0 separator, U+E0B4 closing —
the preset's own. Everything else is the preset's module list verbatim; note it has
no `$cmd_duration`, unlike catppuccin-powerline, so switching presets means
rebuilding this list rather than editing colour names.

**`right_format` does not work here**, which cost a round: in bash starship only
draws a right prompt when ble.sh is attached —

```bash
if [[ ${BLE_ATTACHED-} ]]; then
    bleopt prompt_rps1="$(starship prompt --right ...)"
fi
```

— and plain readline has no right prompt at all. `starship prompt --right` does
print output when called by hand, which is exactly what made the first attempt look
verified when it was not.

### No clock

`$time` is simply left out of the format list, and the closing cap moved from
`color_bg1` to `color_bg3` accordingly. Disabling the `time` module instead would
have left its two surrounding separators behind as a stray coloured block.

### The path

The preset leaves `truncate_to_repo` at its default of `true`, which inside a git
repository collapses the path to just the repository name — which is why the path
looked missing at first. `directory.truncate_to_repo = false` shows the last three
components everywhere instead.

Home Manager merges presets and `settings` with a deep merge
(`tomlq 'reduce .[] as $item ({}; . * $item)'`), `settings` winning, so this lands
inside the preset's existing `[directory]` table rather than colliding with it. The
same rule is why there is no `git_branch.symbol` override: the preset sets its own
Nerd Font glyph, and an override would blank it out.

### Fonts

The preset uses powerline separators and Nerd Font icons. `home/fonts.nix` installs
`pkgs.nerd-fonts.fira-code`, which carries them (checked for U+E0B0 and U+E0A0).

Two things were easy to get wrong here:

**fontconfig has to be told about the Nix profile.** Before this,
`fc-list | grep -c /nix/store` returned 0 and there was no
`~/.config/fontconfig/conf.d`, so a font in `home.packages` would have been
invisible. `fonts.fontconfig.enable = true` generates `10-hm-fonts.conf` and
`52-hm-default-fonts.conf`.

**The terminal has to select it**, and that is per terminal. Ptyxis is handled
declaratively through dconf (see `home/fonts.nix`); its blocker was
`use-system-font = true`, which makes it ignore `font-name` entirely. VSCodium's
integrated terminal is a separate setting (`terminal.integrated.fontFamily`) and is
not managed here.

### Where the old prompt went

`home/bash.nix` no longer sets `PS1`. The starship module injects its init with
`lib.mkOrder 1900`, i.e. after everything that module sets at the default 1000, so
any `PS1` there would be overwritten — dead code rather than a conflict.

The terminal window title could not stay in `PS1` for the same reason, so it moved
to `PROMPT_COMMAND`. That survives because starship's init explicitly preserves an
existing one: it moves the value to `STARSHIP_PROMPT_COMMAND` and evaluates it from
its own `starship_precmd`. One small regression — `\w` abbreviated `$HOME` to `~`,
the replacement prints the full path.

## atuin

Shell history in SQLite instead of `~/.bash_history`, with a searchable UI on
Ctrl-R. `home/atuin.nix` installs it and enables the bash integration, which
sources nixpkgs' `bash-preexec` and evaluates `atuin init bash` from the
generated `~/.bashrc` — so it depends on `home/bash.nix` owning that file.

Kept local:

```nix
settings = {
  auto_sync = false;      # no account, no server
  update_check = false;   # Nix owns the version
};
```

`auto_sync` changes nothing on its own, since sync needs `atuin login` anyway —
it records the intent and stops a later login from quietly starting to upload
history.

### The `?` key

Worth knowing about, because it is easy to miss: as of 18.15.2 the init script
ends with an **unconditional**

```bash
bind -x '"?": _atuin_ai_question_mark'
```

and that widget runs `atuin ai inline` — a network service — whenever `?` is
pressed at an empty prompt. A cloud feature bound to a bare punctuation key is
the wrong default for a history tool meant to stay local, so it is disabled:

```nix
flags = [ "--disable-ai" ];
```

Verified: with the flag the binding is gone, without it it is present.

Two further bindings are left as they are, because they are the point of atuin —
Ctrl-R and Up Arrow both open its search. If the Up Arrow takeover ever gets in
the way, `--disable-up-arrow` restores plain bash history, and
`--disable-ctrl-r` does the same for reverse search.

### Importing existing history

The database starts empty; `~/.bash_history` is not read automatically. One-time:

```bash
atuin import auto
```

## ddev

`pkgs.ddev` from 26.05 (1.25.3 against 1.25.4 upstream -- a single patch, so the
stable channel is fine here, unlike devenv). It provides `ddev`, `ddev-hostname`
and `ddev_gen_autocomplete`.

`mkcert` comes along with it. That is not scope creep: ddev uses it to create a
local CA so `*.ddev.site` gets trusted HTTPS, ddev does not bundle it, and the
package's closure carries only `docker-buildx` -- neither docker nor mkcert.

### Docker has to come from apt

ddev is a thin orchestrator on top of a container runtime, and Nix cannot supply
one here. `pkgs.docker` does exist and includes the daemon, but a daemon on Ubuntu
means a systemd unit and a root-owned socket -- the same wall as `pcscd` in
`home/yubikey.nix`. So the runtime is apt's, and only the runtime.

Ubuntu's `docker.io` (29.1.3) rather than Docker CE from Docker's own repository.
ddev's docs prefer Docker CE, and the honest version of that trade is: `docker.io`
is one major behind at most, is covered by Ubuntu's security updates, and -- the
part that decided it -- it ships the rootless scripts, see below.

### Rootless, not the docker group

The obvious move is `usermod -aG docker "$USER"`, and it is the wrong one. The
`docker` group is not a "non-root docker" switch: anyone in it can ask the
root-owned daemon to bind-mount `/` into a privileged container, so it is
root-equivalent and Docker documents it as such. Rootless mode is the actual
answer -- the daemon runs as christianhuth inside a user namespace, so a container
escape lands on an unprivileged user rather than on root.

The costs are real and worth knowing up front: ports below 1024 need a sysctl (see
below), networking goes through slirp4netns and so is slower than a bridge, and
`--privileged`, host networking and cgroup limits are restricted. For ddev none of
that matters -- it binds 8080/8443-style ports and needs no privileged containers.

ddev supports this explicitly, not incidentally: the binary carries
`IsDockerRootless`, `getDockerRootlessHostIP` and a RootlessKit network-driver
probe over `docker version`, and it names the context in its own error text
(`Check: DOCKER_CONTEXT=rootless docker ps`).

### Setting it up

What was already in place on this machine, verified rather than assumed:

| Prerequisite | State |
| --- | --- |
| `/etc/subuid`, `/etc/subgid` | `christianhuth:100000:65536` |
| cgroup v2 with delegation | `cpu memory pids` under `user@1000.service` |
| `/etc/apparmor.d/rootlesskit` | present, `flags=(unconfined)` with `userns` |
| data-root filesystem | ext4, kernel 7.0 -> native overlay2 in a userns |

That AppArmor profile is the one thing that usually bites on Ubuntu 24.04+.
`kernel.apparmor_restrict_unprivileged_userns=1` means an *unconfined* program
creating a user namespace transitions into `/etc/apparmor.d/unprivileged_userns`,
which carries `audit deny capability` -- fatal for a container runtime. Docker's
own instructions therefore have you hand-write a profile for `~/bin/rootlesskit`.
Not needed here: Ubuntu's `apparmor` package already ships a `rootlesskit` profile
naming exactly apt's `/usr/bin/rootlesskit`, so it gets a named unconfined label
instead of that transition. `fuse-overlayfs` is likewise unnecessary given ext4
plus a 5.11+ kernel.

```bash
# 1. The pieces apt has to provide. uidmap and rootlesskit are hard
#    requirements; one of slirp4netns/pasta/vpnkit is too -- dockerd-rootless.sh
#    aborts without any of them.
sudo apt install docker.io uidmap rootlesskit slirp4netns

# 2. Leave the docker group -- it is root-equivalent and nothing below needs it.
sudo gpasswd -d "$USER" docker

# 3. Stop the rootful daemon. Both units are needed -- the socket would
#    re-activate the service on first use. This is also what unblocks the setup
#    tool in step 5: its guard is `[ -w /var/run/docker.sock ]`, and stopping the
#    units removes that socket.
sudo systemctl disable --now docker.service docker.socket

# 4. Log out and back in. Required twice over: the group change only applies to
#    new sessions, and the setup tool needs a real login session for
#    XDG_RUNTIME_DIR and the user systemd instance.

# 5. Make the setup tool reachable, then run it. Ubuntu keeps the rootless
#    scripts out of PATH under /usr/share/docker.io/contrib, and the tool needs
#    its companion dockerd-rootless.sh on PATH. Symlink rather than prefix PATH
#    -- see "The Ubuntu layout breaks the setup tool" below for why that matters.
sudo ln -s /usr/share/docker.io/contrib/dockerd-rootless.sh /usr/bin/dockerd-rootless.sh
dockerd-rootless-setuptool.sh install

# 6. Start it, and keep it running when no session is open.
systemctl --user enable --now docker
sudo loginctl enable-linger "$USER"

# 7. The local CA for *.ddev.site, once.
mkcert -install
```

Step 5 also creates a docker CLI context called `rootless` and makes it current,
which is why no `DOCKER_HOST` appears anywhere in this repository -- see below.

### The Ubuntu layout breaks the setup tool

Worth knowing, because the first attempt here hit it. The tool resolves its own
install directory from where it finds its companion script:

```sh
BIN="$(command -v dockerd-rootless.sh)"; BIN=$(dirname "$BIN")
```

and then calls `"${BIN}/docker"` -- both for the readiness wait and for all three
context helpers (`context inspect`, `context create`, `context use`). Upstream that
holds, because Docker CE's rootless-extras put `docker` and `dockerd-rootless.sh`
in the same `~/bin`. Ubuntu splits them: `docker` is in `/usr/bin`, the scripts are
in `/usr/share/docker.io/contrib`.

So prefixing PATH with the contrib directory -- the obvious move -- sets
`BIN=/usr/share/docker.io/contrib`, where no `docker` binary exists. The systemd
unit is still written and started correctly, since that happens earlier and uses
the absolute path, but the context step fails silently and you end up with a
working daemon and only a `default` context. Symlinking into `/usr/bin` instead
makes `BIN=/usr/bin`, where both binaries resolve, and the whole tool runs through.

If you already have that half-finished state, the two commands the tool would
have run are enough -- no reinstall:

```bash
docker context create rootless --docker "host=unix:///run/user/$(id -u)/docker.sock" --description "Rootless mode"
docker context use rootless
```

Verify:

```bash
docker context ls          # "rootless" carries the * marker
docker info -f '{{.SecurityOptions}}'   # contains name=rootless
docker run --rm hello-world
ddev list
```

### Ports below 1024

`net.ipv4.ip_unprivileged_port_start` is 1024 here, and a rootless daemon cannot
bind below it. Two ways out, and the second is the better one:

```bash
# Either: let unprivileged processes bind from port 80 on. ddev documents this
# exact snippet, but it lowers the limit for every process on the machine.
echo 'net.ipv4.ip_unprivileged_port_start=0' | sudo tee /etc/sysctl.d/60-rootless.conf
sudo sysctl --system

# Or: move ddev's router up, and change nothing system-wide.
ddev config global --router-http-port=8080 --router-https-port=8443
```

ddev 1.25.3 is also past the window where rootless needed
`ddev config global --no-bind-mounts` -- that applied to 1.25.0 through 1.25.2.

### Why DOCKER_HOST is not set declaratively

It would be the obvious thing to add to `home/ddev.nix`, and it is deliberately
absent. The `rootless` CLI context carries the same information, and both tools
read it -- confirmed rather than assumed:

```
$ ddev debug dockercheck
Docker platform: linux-docker-rootless
Using Docker context: rootless
Using Docker host: unix:///run/user/1000/docker.sock
```

So the variable is redundant. It is also not inert: `DOCKER_HOST` takes precedence
over the context, so a later `docker context use` would silently do nothing. And
the context lives in `~/.docker`, which the CLI rewrites itself -- mutable state,
left where it belongs, same reasoning as ddev's own config below.

### Its config stays mutable

ddev writes `~/.ddev/global_config.yaml`, `project_list.yaml` and a
`homeadditions/` tree on first run, and rewrites them through `ddev config
global`. None of that is declared here. Nix managing a file the tool itself keeps
rewriting is the trap that already cost a round with atuin's `config.toml`.

## devenv

`pkgs.devenv` comes from **nixos-unstable** through `pkgs/overlay.nix`, the same
route as signal-desktop. nixpkgs 26.05 sits at 2.1.2 while upstream released 2.4.0
on 2026-09-24, which is exactly what unstable carries. Three minor versions matter
for this tool: `devenv.nix` options and the module schema change between them, and
an old binary rejects a current `devenv.nix` with a version error rather than
degrading gracefully.

Verified in the profile: `devenv-2.4.0`.

### It is not wired into direnv

`devenv direnvrc` exists, and `home/direnv.nix` puts nix-direnv's equivalent into
`~/.config/direnv/lib/`, so the obvious move would be to do the same here. That
would break `use flake`.

devenv's direnvrc describes itself as "adapted from nix-community/nix-direnv", and
it redefines three of nix-direnv's functions:

```
_nix_direnv_preflight
_nix_export_or_unset
_nix_import_env
```

direnv sources `~/.config/direnv/lib/*.sh` in glob order, so whichever file sorts
last wins all three. Neither order is safe:

| Order | Consequence |
|---|---|
| `devenv.sh` before `hm-nix-direnv.sh` | `use_devenv` silently runs nix-direnv's preflight, which checks for `nix` rather than `devenv` |
| `devenv.sh` after | `use flake` -- which this repository's own `.envrc` pattern relies on -- loses its helpers |

So devenv's direnvrc belongs in the `.envrc` of the project that wants it, where its
definitions are scoped to that one evaluation:

```bash
source_url "https://raw.githubusercontent.com/cachix/devenv/v2.4.0/direnvrc" \
  "sha256-..."
use devenv
```

A project uses either `use flake` or `use devenv`, never both, so scoping it per
project costs nothing. Confirmed after the change: `~/.config/direnv/lib/` still
contains only `hm-nix-direnv.sh`.

### The binary cache cannot be added from here

devenv's documentation recommends `https://devenv.cachix.org` as a substituter. That
is not reachable from this configuration:

```
$ nix config show trusted-users
root
```

A non-root user's `substituters` are ignored unless the user is trusted, so this
needs `/etc/nix/nix.conf`. Worth doing only if devenv turns out to build a lot
locally -- devenv itself arrives prebuilt from `cache.nixos.org`.

## direnv

`home/direnv.nix` enables direnv 2.37.1 together with **nix-direnv** 3.1.2. The
latter is the part that matters on a Nix machine: it replaces direnv's own
`use_nix` / `use_flake` with an implementation that caches the evaluated
environment and anchors it as a GC root. Without it, entering a project directory
re-evaluates every time, and `nix-collect-garbage` can remove the result from
under it.

The option is `nix-direnv.enable`; the older `enableNixDirenvIntegration` is only
a deprecated alias.

Generated files:

| Path | Purpose |
|---|---|
| `~/.config/direnv/lib/hm-nix-direnv.sh` | nix-direnv's `use_flake`/`use_nix`, loaded from direnv's `lib/` so it composes with a hand-written `direnvrc` |
| end of `~/.bashrc` | `eval "$(direnv hook bash)"`, placed via `mkAfter` so it comes after anything touching the prompt |

Not set yet: `silent = true`, which would add `log_format = "-"` and
`log_filter = "^$"` to `direnv.toml` and stop direnv from listing the loaded
variables on every directory change. Left off until it has been seen how chatty
it is in practice. Note the option is called `silent` — there is no
`hide_env_diff` in this module.

Per project, direnv still needs an `.envrc` (`use flake` for this kind of
repository) and a one-time `direnv allow`.

## ykman

`pkgs.yubikey-manager` (5.9.1, newer than Ubuntu's apt 5.8.0-4) provides the
`ykman` binary — note the attribute and the command have different names.

Installing it is not a working setup on its own, and `ykman info` says so:

```
WARNING: PC/SC not available. Smart card (CCID) protocols will not function.
Device type: YubiKey 5C NFC
Enabled USB interfaces: OTP, FIDO, CCID
```

### Why, measured rather than assumed

With the key plugged in (USB `1050:0407`), the two HID interfaces differ:

| Device | Permissions | Meaning |
|---|---|---|
| `/dev/hidraw1` | ACL `christianhuth:rw-` | FIDO — works |
| `/dev/hidraw0` | `crw------- root root` | OTP — no access |

The asymmetry is a udev chain. systemd's `70-uaccess.rules` line 60 reads

```
ENV{ID_SECURITY_TOKEN}=="?*", TAG+="uaccess"
```

and `60-fido-id.rules` only sets that variable on the FIDO interface. Yubico's own
`69-yubikey.rules` sets it by USB product id instead — `0407` is listed explicitly
— so it covers the OTP interface too.

### The two system prerequisites

Both are outside what Home Manager can reach off NixOS: a rule in `/etc/udev` and a
daemon with a systemd unit.

```bash
sudo apt install pcscd                    # PIV, OATH and OpenPGP applets
sudo apt install yubikey-personalization  # ships 69-yubikey.rules -> OTP applet
```

Only the library `libpcsclite1` was installed here; the `pcscd` daemon was missing
entirely (`pcscd.service` inactive, `pcscd.socket` not-found). FIDO/WebAuthn works
without either package.

Both rules could in principle come from Nix — `pkgs.yubikey-personalization` ships
the same `lib/udev/rules.d/69-yubikey.rules` — but the root-side install and the
udev reload would be a manual step either way, and a daemon needs its unit. apt is
the honest answer for this half.

### One interaction with gnupg

gpg-agent's `scdaemon` and `pcscd` both want the card and can lock each other out
("card busy"). If the OpenPGP applet is ever driven from gpg,
`programs.gpg.scdaemonSettings` is where that gets settled — typically
`disable-ccid = true`, so scdaemon goes through pcscd rather than driving the reader
itself. Not configured until it is actually needed.

## WireGuard via NetworkManager

`home/wireguard.nix` imports every `~/.wireguard/*.conf` into NetworkManager.
The tunnel configurations themselves stay **outside** this repository, and that
is not only a preference: they contain WireGuard private keys, and everything in
`/nix/store` is world-readable. Nix orchestrates the import; it never holds the
secrets. NetworkManager's own copy under `/etc/NetworkManager/system-connections`
is mode 0600 and root-owned, i.e. stricter than the source file.

The logic lives in a `writeShellApplication` that is both run from
`home.activation` and exposed as the command `wireguard-nm-import`, so a newly
dropped `.conf` can be picked up without a full switch. It is idempotent: a
tunnel NetworkManager already knows is skipped.

Three decisions in there are deliberate:

**Ubuntu's `nmcli`, not nixpkgs'.** `nmcli` talks to the running NetworkManager
over D-Bus, and the versions differ — Ubuntu runs 1.54.3, nixpkgs 26.05 ships
1.56.0. Matching the daemon is safer, the same reasoning as for gpg and its
agent.

**The directory is managed, its contents are not.** The script creates
`~/.wireguard` and enforces mode `0700` on every run, because the files inside
hold WireGuard private keys. Two other routes were considered and rejected:
`home.file` would turn the directory into a symlink into the store, which
conflicts with the configurations having to stay mutable and outside Nix; and
`systemd.user.tmpfiles` would install four of nixpkgs' systemd units plus a
cleanup timer into `~/.config/systemd/user` and run `systemd-tmpfiles --remove`
— a lot of machinery, and cleanup semantics next to private keys, in exchange for
one `mkdir`.

An empty or missing directory is handled: `shopt -s nullglob` makes the pattern
expand to nothing instead of iterating over the literal `*.conf`, and the script
says so rather than failing. Verified for all three cases — missing directory,
empty directory, and a loosened mode being tightened back to `0700`.

**Imported tunnels are taken down again.** `nmcli connection import` activates
the profile immediately: at that moment its `autoconnect` is still at the default
of `yes`, so NetworkManager brings the tunnel up. Setting `autoconnect` afterwards
only affects later boots and leaves the running tunnel in place — which is why a
first run appeared to ignore the setting and started everything at once. The
script therefore takes anything down explicitly that is not on the autoconnect
list.

**Autoconnect is opt-in per tunnel, and reconciled.** All five configurations
are split tunnels (no `0.0.0.0/0`), so they do not fight over the default route
and could in principle all run at once — but VPNs coming up by themselves are
surprising. The list is currently empty, so every tunnel is brought up by hand:

```nix
autoconnect = [ ];
```

The setting is applied on **every** run, not only at import, so this list is the
single source of truth — adding or removing a name and switching is enough. What
the script does *not* do on a reconcile is change the running state: autoconnect
governs boot behaviour, and tearing down a tunnel someone is using because a
switch happened to run would be hostile. At import time it does take the tunnel
down, because there the tunnel was started as a side effect rather than by
anyone's choice.

A note on how the list is rendered: `$name` has to be the `case` subject rather
than the list, otherwise the subject is a constant after Nix interpolation and
ShellCheck flags SC2194 — which it did, failing the build until it was turned
around. That check runs on every build, which is the point of using
`writeShellApplication` instead of a bare string.

**`runtimeInputs` declared strictly.** `writeShellApplication` only *prefixes*
PATH, so an undeclared tool silently falls through to Ubuntu's copy and breaks
the day that changes. `nmcli` is the one deliberate exception, for the version
reason above.

### Volatile connections

`nmcli -t -f NAME,FILENAME connection show` shows where each profile is stored,
and on this machine nearly all of them sit under
`/run/NetworkManager/system-connections` — tmpfs. That is **not** a problem by
itself: Ubuntu lets netplan own NetworkManager's profiles, so `/etc/netplan`
holds the source and `/run` only the render.

The distinguishing mark is the filename. Netplan renders as
`netplan-<something>.nmconnection`; a file in `/run` *without* that prefix has no
netplan source and exists in tmpfs only:

| Connection | File in `/run` | Verdict |
|---|---|---|
| Wi-Fi ×3, `netplan-enp1s0f0` | `netplan-NM-<uuid>…`, `netplan-enp1s0f0…` | persistent |
| `defra` (imported through this module) | `netplan-defra.nmconnection` | persistent |
| `lo`, `Wired connection 1` | plain names | volatile, but NetworkManager-generated defaults |
| `mgmt2` | `mgmt2.nmconnection` | **volatile, and it matters** |

A fresh `nmcli connection import` is picked up by netplan, which writes
`/etc/netplan/90-NM-<uuid>.yaml` and renders into `/run` — verified by importing
`defra`. So `mgmt2` was presumably imported with `--temporary` at some point; the
fix is to re-import it:

```bash
nmcli connection delete mgmt2
home-manager switch --flake .#christianhuth
```

Deleting it first and letting the switch re-import is the simpler route: the
activation step picks up everything NetworkManager does not know, so the same run
also handles any tunnel still missing. Be aware that the delete tears down the
tunnel if it is currently up.

The import script applies exactly the heuristic above and only warns for the
genuinely volatile case. It never re-imports on its own, since that would drop a
live tunnel.

## Mixing channels: Signal from unstable

`flake.nix` pulls in a second input, `nixpkgs-unstable`, and `pkgs/overlay.nix`
takes exactly one package from it.

The reason is specific to Signal: **Signal Desktop expires.** Roughly 90 days
after its build date it refuses to start, and a stable-channel pin therefore
does not merely mean older features, it means the program eventually stops
working with no way around it but an update. Stable had 8.25.0, unstable has
8.26.0.

Be aware this is still not the newest release — upstream was at 8.28.0 — so
`nix flake update` is not optional here, it is maintenance. If Signal ever
refuses to start, that is the first thing to run.

Mixing channels has a cost worth knowing: the unstable package set brings its
own dependency closure, so you pay disk and download for a second copy of much
of the graph. Take single packages from it, not whole categories.

## Electron applications on Ubuntu

Every Electron app installed through Nix hits the same wall on Ubuntu 24.04 and
later, because Ubuntu sets `kernel.apparmor_restrict_unprivileged_userns = 1`:
unconfined binaries may not create user namespaces, which is what Chromium's
sandbox needs. The older SUID sandbox is no fallback either, since nothing in
`/nix/store` can be setuid. The app aborts rather than run unsandboxed.

Two profiles handle this, both following Ubuntu's own pattern for Chromium-based
programs — grant `userns`, leave the program otherwise unconfined, keep the
sandbox intact:

| Profile | Attaches to | Covers |
|---|---|---|
| `system/apparmor/nix-electron` | `…-electron-unwrapped-*/libexec/electron/electron` | every app using nixpkgs' Electron (Signal) |
| `system/apparmor/termius` | `…-termius-*/opt/Termius/termius-app` | Termius, which bundles its own Electron |

```bash
sudo install -Dm644 system/apparmor/nix-electron /etc/apparmor.d/nix-electron
sudo install -Dm644 system/apparmor/termius      /etc/apparmor.d/termius
sudo apparmor_parser -r /etc/apparmor.d/nix-electron
sudo apparmor_parser -r /etc/apparmor.d/termius
```

Both attachment paths are globbed, so they survive rebuilds and version bumps
and only need installing once. On NixOS this would be `security.wrappers`
instead, in the configuration proper.

## The root prompt

`homeConfigurations.root` gives root the same prompt. This is the multi-user case
the section below sketches, in practice: two users means **two Home Manager
generations**, applied separately.

`home/root.nix` imports `./bash.nix` and `./starship.nix` and nothing else. Both
are user-agnostic — neither references a username or a user-specific path — so the
two shells stay consistent instead of drifting. Verified: the generated
`starship.toml` is byte-identical for both users.

Deliberately *not* imported is `targets.genericLinux.enable`. It exists to put the
Nix profiles into `XDG_DATA_DIRS` so desktop entries and icons are found, and it
pulls in the `non-nixos-gpu` helper. A root shell needs neither.

Root's generation writes eight files to `/root`: `.bashrc`, `.profile`,
`.bash_profile`, `.config/starship.toml` and Home Manager's own bookkeeping.

### Root is red

gruvbox-rainbow sets `style_user` and `style_root` to the *same*
`bg:color_orange fg:color_fg0`, so a root shell is indistinguishable at a glance.

Fixing only `username.style_root` is not enough, and that was the first attempt:
it turns the name red but leaves the distro icon in front of it and the triangle
behind it orange, because those are the `$os` module and the separator — plain
static styles. starship can only branch on the current UID inside the `username`
module; everything else is fixed text.

So the accent is decided at **evaluation** time instead, by which configuration is
being built:

```nix
isRoot = config.home.username == "root";
accent = if isRoot then "color_red" else "color_orange";
```

`home/root.nix` sets `home.username = "root"`, so the two generated
`starship.toml` files differ in exactly three lines — verified by diffing them:

| | christianhuth | root |
|---|---|---|
| leading cap and separator in `format` | `color_orange` | `color_red` |
| `[os] style` | `bg:color_orange` | `bg:color_red` |
| `[username] style_user` | `bg:color_orange` | `bg:color_red` |

Confirmed down to the escape codes: `214;93;14` versus `204;36;29`.

`username.style_root` is kept red independently of `accent`, as a fallback for a
shell that runs *this* user's configuration while being root — `sudo -s` keeps
`HOME` under Ubuntu's default sudoers. In that case the name goes red but the
surrounding segment stays orange, which cannot be helped from the configuration.
`sudo -i` is the clean way in.

### Applying it

Root's switch is separate and has to run as root:

```bash
sudo env PATH=/nix/var/nix/profiles/default/bin:/usr/bin:/bin \
  /nix/var/nix/profiles/default/bin/nix run home-manager/release-26.05 \
  -- switch -b backup --flake /home/christianhuth/code/christianhuth/nix-config#root
```

`-b backup` is needed on the **first** root switch for the same reason it was for
christianhuth: Ubuntu ships `/root/.profile` and `/root/.bashrc` from
`/etc/skel`, and Home Manager refuses to replace existing files. They end up as
`.profile.backup` and `.bashrc.backup`.

Nothing is lost by that. Root's `sbin` PATH does not come from those files —
`/etc/profile` on this system only sets `PS1`, and the PATH comes from
`/etc/environment` via PAM, which Home Manager does not touch.

Both halves of that are needed, and calling `nix` by absolute path alone is not
enough — that fails with:

```
home-manager: line 594: nix: command not found
```

sudo's `secure_path` does not contain the Nix profile, and **two** things
downstream look `nix` up by name:

* the `home-manager` script sets its own PATH (coreutils, jq, gnused, …) but
  deliberately leaves nix out, expecting it to be there already — then calls
  `nix` 62 times plus `nix-build`, `nix-env`, `nix-instantiate` and `nix-store`;
* the generation's `activate` script derives its nix directory from
  `$(dirname $(readlink -m $(type -p nix-env)))`, so without `nix-env` on PATH it
  puts a garbage entry there and every nix call fails.

`env` is found through `secure_path`, sets PATH for the whole process tree and
then execs nix. `/usr/bin:/bin` is included for the activation's system tools;
the user's own profile is deliberately *not* on that PATH, so root does not end
up running binaries out of `~christianhuth`.

The flake path is absolute because root's working directory is not this
repository. Reading a repository owned by another user works — `sudo nix profile
add .#system-packages` has been doing it all along.

A permanent alternative is putting the Nix profile into sudo's `secure_path`,
which would also shorten the layer-1 commands. Do it through
`sudo visudo -f /etc/sudoers.d/nix` so the syntax is validated before saving, and
copy the existing value first (`sudo grep secure_path /etc/sudoers`) — the
directive replaces rather than appends, and a malformed sudoers file locks sudo.

The cost of this arrangement: forgetting root's switch lets it drift from the
user's. There is no mechanism here that applies both at once.

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
