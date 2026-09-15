# Bootstrap (one-time setup)

```bash
# 0. Prerequisites
sudo apt install -y curl git xz-utils

# 1. Install Nix (multi-user/daemon). Open a new shell afterwards!
sh <(curl -L https://nixos.org/nix/install) --daemon

# 2. Enable flakes
sudo mkdir -p /etc/nix
echo 'experimental-features = nix-command flakes' | sudo tee -a /etc/nix/nix.conf
sudo systemctl restart nix-daemon
```

That is all. No manual `~/.bashrc` edit is needed: `home/bash.nix` enables
`programs.bash`, so Home Manager generates `~/.bashrc`, `~/.profile` and
`~/.bash_profile` itself and sources `hm-session-vars.sh` from there — which is
what puts entries like `~/.krew/bin` on PATH.

Because Home Manager takes those files over, the **first** `home-manager
switch` would collide with Ubuntu's existing ones. Running it with `-b backup`
(see [README.md](README.md#applying)) moves them aside as `~/.bashrc.backup`
and `~/.profile.backup` instead of aborting. Ubuntu's defaults from those files
that are worth keeping — the coloured prompt, the `ls`/`grep` colour aliases,
`ll`/`la`/`l`, lesspipe and the `~/.local/bin` PATH entry — are already ported
into `home/bash.nix`.

Open a new terminal afterwards so the generated files are read.
