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

      # Ubuntu's coloured prompt. The debian_chroot prefix is dropped: there is
      # no /etc/debian_chroot here, so it only ever expanded to nothing.
      PS1='\[\033[01;32m\]\u@\h\[\033[00m\]:\[\033[01;34m\]\w\[\033[00m\]\$ '

      # Put user@host: cwd into the terminal window title.
      case "$TERM" in
        xterm*|rxvt*) PS1="\[\e]0;\u@\h: \w\a\]$PS1" ;;
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
