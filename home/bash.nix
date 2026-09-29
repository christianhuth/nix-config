{ ... }:

{
  # With this enabled, Home Manager writes ~/.bashrc, ~/.profile and
  # ~/.bash_profile wholesale -- which is the point of a declarative setup,
  # but it does mean Ubuntu's /etc/skel defaults are replaced. The parts of
  # those defaults worth keeping are ported below.
  #
  # Generated layout:
  #   ~/.bash_profile  sources ~/.profile, then ~/.bashrc
  #   ~/.profile       hm-session-vars.sh, sessionVariables, profileExtra
  #   ~/.bashrc        bashrcExtra, interactive guard, history, shell options,
  #                    shellAliases, initExtra
  #
  # Note that the login shell in /etc/passwd stays Ubuntu's /bin/bash. Home
  # Manager cannot change that off NixOS, and it does not need to -- that bash
  # reads the files generated here just the same.
  programs.bash = {
    enable = true;

    # Home Manager already defaults to histappend, extglob, globstar and
    # checkjobs; checkwinsize is the one Ubuntu had that is missing there.
    shellOptions = [
      "histappend"
      "extglob"
      "globstar"
      "checkjobs"
      "checkwinsize"
    ];

    # Ubuntu's default. Home Manager leaves this empty, and its history sizes
    # (10000 / 100000) are already more generous than Ubuntu's 1000 / 2000.
    historyControl = [ "ignoreboth" ];

    shellAliases = {
      ll = "ls -alF";
      la = "ls -A";
      l = "ls -CF";
    };

    initExtra = ''
      # Make less friendlier for non-text input files.
      [ -x /usr/bin/lesspipe ] && eval "$(SHELL=/bin/sh lesspipe)"

      # Colour support for ls and grep.
      if [ -x /usr/bin/dircolors ]; then
        test -r ~/.dircolors && eval "$(dircolors -b ~/.dircolors)" || eval "$(dircolors -b)"
        alias ls='ls --color=auto'
        alias grep='grep --color=auto'
        alias fgrep='fgrep --color=auto'
        alias egrep='egrep --color=auto'
      fi

      # No PS1 here any more: home/starship.nix owns the prompt. Its init is
      # injected with lib.mkOrder 1900, i.e. after this block at the default
      # 1000, so anything set here would be overwritten anyway.
      #
      # The window title still has to live somewhere, and it cannot ride along
      # in PS1 for the same reason. PROMPT_COMMAND works instead: starship's
      # init preserves an existing one rather than clobbering it -- it moves the
      # value to STARSHIP_PROMPT_COMMAND and evaluates that from its own
      # starship_precmd.
      #
      # Slight difference to the old PS1 version: \w abbreviated $HOME as "~",
      # this prints the full path.
      case "$TERM" in
        xterm*|rxvt*)
          PROMPT_COMMAND='printf "\033]0;%s@%s: %s\007" "$USER" "$HOSTNAME" "$PWD"'
          ;;
      esac
    '';
  };

  # Ubuntu's ~/.profile put these on PATH when the directories existed.
  # Neither exists yet; a missing PATH entry is harmless.
  home.sessionPath = [
    "$HOME/.local/bin"
    "$HOME/bin"
  ];
}
