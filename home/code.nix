# Layout of ~/code: the directories that should always exist, plus the one
# .envrc that is managed declaratively.
#
# Contents of these directories are deliberately NOT managed here -- they hold
# working copies, which have to stay mutable. See README.md for why cloning
# repositories is a separate question.
{
  config,
  lib,
  pkgs,
  ...
}:

let
  codeDir = "${config.home.homeDirectory}/code";

  # Repositories to have on disk, keyed by their path below ~/code.
  #
  # Cloned **once**, only when the target directory does not exist. Never pulled:
  # re-pulling on every switch would run into dirty working trees and
  # half-finished branches. Nix declares which repository belongs where; git does
  # the cloning, and the working copies stay entirely outside Nix.
  #
  # The URLs deliberately drop the "christian.huth@" that the existing clones
  # carry in their remotes. pass-git-helper supplies the username itself now
  # (username_extractor = "static" in home/gnupg.nix), so embedding it is
  # redundant -- and it was only ever there to work around the username that the
  # helper did not return.
  #
  # All three carry the .git suffix: without it GitLab answers with a redirect
  # ("warning: redirecting to .../pmcp-base.git/"), which works but is noise.
  #
  # `branch` is optional and defaults to whatever the remote's default is. Set it
  # only for a repository that has to sit on a specific branch, e.g.
  #   "proact/ansible/base" = { url = "..."; branch = "stable-20260626"; };
  repos = {
    "proact/ansible/base".url = "https://gitlab.proact.eu/paas/pmcp-base.git";
    "proact/ansible/operational-scripts".url = "https://gitlab.proact.eu/paas/operational-scripts.git";
    "proact/ansible/site".url = "https://gitlab.proact.eu/paas/site.git";
  };

  cloner = pkgs.writeShellApplication {
    name = "code-repos-clone";
    runtimeInputs = [
      config.programs.git.package
      pkgs.coreutils
    ];
    text = ''
      # Never block on a terminal prompt: credentials come from pass-git-helper
      # (home/git.nix), which in turn needs gpg-agent. If that chain is not ready
      # -- a fresh machine, a locked agent -- the clone should fail visibly rather
      # than hang inside `home-manager switch`.
      export GIT_TERMINAL_PROMPT=0

      clone_one() {
        local dir="$1" url="$2" branch="$3"

        if [ -e "$dir" ]; then
          echo "code-repos: $dir exists, leaving it alone"
          return 0
        fi

        echo "code-repos: cloning $url into $dir"
        mkdir -p "$(dirname "$dir")"

        if [ -n "$branch" ]; then
          git clone --branch "$branch" -- "$url" "$dir" ||
            echo "code-repos: cloning $url failed -- run 'code-repos-clone' by hand once credentials work" >&2
        else
          git clone -- "$url" "$dir" ||
            echo "code-repos: cloning $url failed -- run 'code-repos-clone' by hand once credentials work" >&2
        fi
      }

      ${lib.concatStringsSep "\n      " (
        lib.mapAttrsToList (
          path: r:
          "clone_one ${lib.escapeShellArg "${codeDir}/${path}"} ${lib.escapeShellArg r.url} ${
            lib.escapeShellArg (r.branch or "")
          }"
        ) repos
      )}
    '';
  };

  # Kept present and otherwise empty. Home Manager creates parent directories
  # for files it links anyway, so proact/ansible would appear via the .envrc
  # below -- it is listed regardless so the intent is readable in one place.
  dirs = [
    "proact/ansible"
    "typo3/extensions"
    "typo3/sitepackages"
  ];
in
{
  # `home.file` cannot express "an empty mutable directory": it would either
  # need a placeholder file in each one or turn them into store symlinks, and
  # these have to stay ordinary writable directories. So: mkdir, idempotent.
  home.activation.codeDirs = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    for d in ${lib.escapeShellArgs (map (d: "${codeDir}/${d}") dirs)}; do
      run mkdir -p "$d"
    done
  '';

  # Also a command, so a repository added to the list above can be fetched
  # without a full switch -- and so a clone that failed for want of credentials
  # can simply be retried in an interactive shell.
  home.packages = [ cloner ];

  # Runs after the directories exist. Idempotent, and `|| true` keeps a failed
  # clone from aborting the activation.
  home.activation.codeRepos = lib.hm.dag.entryAfter [ "codeDirs" ] ''
    run ${lib.getExe cloner} || true
  '';

  # Taken over verbatim from the existing local file. Safe to keep in the
  # repository: it contains no secret itself, it *fetches* one through
  # `pass show proact/ssh-password` -- see home/gnupg.nix.
  #
  # Two consequences of managing it here:
  #
  #   * The file becomes a read-only symlink into the store. Editing happens in
  #     this repository followed by a switch, not in ~/code.
  #   * direnv records an allow-token per file content, so after a change here
  #     the directory needs `direnv allow` once more.
  #
  # `layout_python3` builds a virtualenv from whatever python3 is on PATH --
  # Ubuntu's, since none is installed through Nix. uv (home/default.nix) then
  # works inside that virtualenv.
  #
  # One thing worth checking against your Ansible version: the variable for a
  # password *file* is ANSIBLE_VAULT_PASSWORD_FILE. ANSIBLE_VAULT_PASSWORD, as
  # used below, is the password itself in the versions that support it -- so
  # pointing it at a script path may not do what it looks like. Carried over
  # unchanged for now rather than silently "fixed".
  home.file."code/proact/ansible/.envrc" = {
    # Without this, Home Manager finds the pre-existing local file and reports
    # "will be skipped since they are the same" -- which leaves it a plain file
    # that Nix does not own. The first content change here would then fail the
    # switch with "would be clobbered". Forcing it makes the symlink happen now,
    # while the content is still identical and nothing can be lost.
    force = true;

    text = ''
      layout_python3

      export ANSIBLE_BECOME_PASS=$(pass show proact/ssh-password | head -n 1)
      export ANSIBLE_VAULT_PASSWORD_FILE=$(pwd)/operational-scripts/bin/ansible-vault-password.sh
    '';
  };
}
