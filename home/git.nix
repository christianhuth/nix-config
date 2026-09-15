{ ... }:

{
  programs.git = {
    enable = true; # installs git as well -- that is why it is not in home.packages

    # Writes ~/.config/git/config, i.e. exactly the file that
    # `git config --global` touches. Note that an existing ~/.gitconfig takes
    # precedence over this file; there is none on this machine.
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

      # --- Convenience ------------------------------------------------------
      # Show the full diff in the editor while writing the commit message.
      commit.verbose = true;
    };
  };
}
