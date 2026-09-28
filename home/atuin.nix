{ ... }:

{
  programs.atuin = {
    enable = true; # installs atuin itself

    # Sources nixpkgs' bash-preexec and runs `atuin init bash` from the generated
    # ~/.bashrc. This depends on home/bash.nix owning that file; without
    # programs.bash enabled the integration would land nowhere.
    #
    # The module guards it on $SHELLOPTS containing vi or emacs, so it only takes
    # effect in shells with line editing.
    enableBashIntegration = true;

    # Passed to `atuin init bash`. As of 18.15.2 the init script ends with an
    # unconditional
    #   bind -x '"?": _atuin_ai_question_mark'
    # and that widget calls `atuin ai inline`, i.e. a network service, whenever ?
    # is pressed at an empty prompt. For a history tool that is meant to stay
    # local, a cloud feature bound to a bare punctuation key is the wrong default,
    # so it is turned off.
    #
    # Also available if the other bindings get in the way:
    #   --disable-up-arrow   keeps Up as plain bash history
    #   --disable-ctrl-r     keeps Ctrl-R as plain reverse search
    # Both are left enabled -- they are what atuin is for.
    flags = [ "--disable-ai" ];

    # Atuin writes its own default config.toml whenever the file is missing --
    # merely running `atuin --version` is enough. That makes `rm` followed by a
    # switch a race, and without this Home Manager refuses with
    #   Existing file '~/.config/atuin/config.toml' would be clobbered
    # This sets `force = true` on that file entry so the generated config wins.
    # Nothing of value is lost: anything atuin writes there is its defaults, and
    # real settings belong in the attribute set below.
    forceOverwriteSettings = true;

    # Written to ~/.config/atuin/config.toml.
    settings = {
      # Local only: no account, no server. Sync requires `atuin login` anyway,
      # so this changes no behaviour by itself -- it records the intent, and
      # prevents a later login from quietly starting to upload history.
      auto_sync = false;

      # Nix owns the version, so atuin phoning home for a newer one is noise.
      update_check = false;
    };
  };
}
