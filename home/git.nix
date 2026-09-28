{ ... }:

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

      # Rebase instead of merge on pull, so no accidental merge commits.
      # Opinionated: `pull.ff = "only"` is the stricter alternative, which
      # refuses the pull instead of rebasing and lets you decide.
      pull.rebase = true;

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
      credential.helper = "!pass-git-helper $@";

      # --- Convenience ------------------------------------------------------
      # Show the full diff in the editor while writing the commit message.
      commit.verbose = true;
    };
  };
}
