{
  config,
  lib,
  pkgs,
  ...
}:

{
  programs.git = {
    enable = true; # installs git as well -- that is why it is not in home.packages

    # Writes ~/.config/git/config, i.e. exactly the file that
    # `git config --global` touches.
    #
    # Careful: git reads both this file and ~/.gitconfig, and ~/.gitconfig wins
    # for single-valued variables. A leftover ~/.gitconfig here currently
    # duplicates init.defaultBranch with the same value, so it is harmless --
    # but it would silently override a change made here. See README.md.
    #
    # In Home Manager 26.05 this option is called `settings`;
    # `extraConfig` still works but is a deprecated alias. The same applies to
    # `userName`/`userEmail`, which are now settings.user.name/.email.
    settings = {
      # --- Identity -----------------------------------------------------
      # Without these, git refuses to commit.
      user = {
        name = "Christian Huth";
        email = "christian@knell.it";
      };

      # --- Branch naming --------------------------------------------------
      init.defaultBranch = "main";

      # --- Push / pull ----------------------------------------------------
      # Pushing a new branch no longer needs `--set-upstream` (git >= 2.37).
      push.autoSetupRemote = true;

      # Kept as false to match the long-standing setting from the previous
      # machine. This repository originally set `true` (rebase on pull, no
      # accidental merge commits); `pull.ff = "only"` would be the stricter
      # middle ground, refusing the pull instead of deciding for you. Changing
      # it is a one-line edit -- but it should be a deliberate one.
      pull.rebase = false;

      # Let rebase stash and restore a dirty working tree by itself.
      rebase.autoStash = true;

      # Drop local references to branches that were deleted on the remote.
      fetch.prune = true;

      # --- Diff / merge quality -------------------------------------------
      # zdiff3 also shows the common ancestor inside conflict markers, which
      # usually makes it obvious which side changed what (git >= 2.35).
      merge.conflictStyle = "zdiff3";

      # Noticeably better diffs than the default Myers algorithm, especially
      # when code was moved or indentation changed.
      diff.algorithm = "histogram";

      # Remember how a conflict was resolved and reapply it if the same
      # conflict shows up again (rebases, cherry-picks, long-lived branches).
      rerere.enabled = true;

      # --- Credentials ------------------------------------------------------
      # pass-git-helper resolves credentials from the pass store. The leading
      # `!` tells git to run the value as a shell command. The tool itself is
      # installed in home/gnupg.nix, and it needs a host-to-entry mapping in
      # ~/.config/pass-git-helper/git-pass-mapping.ini -- see README.md.
      credential = {
        helper = "!pass-git-helper $@";

        # GitHub is handled by `gh` rather than pass, because gh manages and
        # refreshes its own OAuth token.
        #
        # The empty first element is load-bearing: git accumulates
        # credential.helper values into a list, so without resetting it here
        # pass-git-helper would still be asked for github.com first. An empty
        # value clears the inherited list for this URL.
        #
        # The old machine hardcoded /usr/bin/gh, which does not exist here --
        # gh now comes from Nix. lib.getExe resolves to the store path, so this
        # cannot silently break.
        "https://github.com".helper = [
          ""
          "!${lib.getExe pkgs.gh} auth git-credential"
        ];
        "https://gist.github.com".helper = [
          ""
          "!${lib.getExe pkgs.gh} auth git-credential"
        ];
      };

      # --- Convenience ------------------------------------------------------
      # Show the full diff in the editor while writing the commit message.
      commit.verbose = true;
    };

    # Conditional configuration, replacing the old
    #   [includeIf "gitdir:~/code/proact/"] path = ~/.gitconfig-proact
    # Using `contents` instead of `path` keeps the work identity in this
    # repository; Home Manager generates the included file and points git at it,
    # so there is no separate ~/.gitconfig-proact to maintain by hand.
    includes = [
      {
        condition = "gitdir:~/code/proact/";
        contents = {
          user = {
            name = "Christian Huth";
            email = "christian.huth@proact.eu";
            # The work GPG key; its UID carries the same address as user.email
            # above, which Forgejo requires to mark a commit as "Verified".
            signingKey = "175F8A4C86918611";
          };

          # Sign only work commits and tags -- private repositories stay
          # unsigned, which is why this lives here and not in `settings`.
          commit.gpgSign = true;
          tag.gpgSign = true;

          # Use the gpg from home/gnupg.nix, the one talking to the Nix-managed
          # gpg-agent, instead of whichever `gpg` comes first in PATH.
          gpg.program = lib.getExe config.programs.gpg.package;
        };
      }
    ];
  };
}
