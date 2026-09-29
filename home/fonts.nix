{ pkgs, ... }:

{
  # fontconfig has to be pointed at the Nix profile, otherwise fonts installed
  # through home.packages stay invisible to applications. This is not already on:
  # before enabling it, `fc-list | grep -c /nix/store` returned 0 and there was no
  # ~/.config/fontconfig/conf.d at all.
  fonts.fontconfig.enable = true;

  home.packages = [
    # Needed by the catppuccin-powerline starship preset, which uses 28
    # private-use-area glyphs: powerline separators (U+E0B0, U+E0B4, U+E0B6) plus
    # Nerd Font icons for the OS and language modules. Without a font carrying
    # them the prompt renders as replacement boxes -- `fc-list :charset=e0a0`
    # previously matched zero fonts on this machine.
    #
    # Installing it is only half the job -- the terminal has to be told to use
    # it. That part is declared below rather than clicked.
    pkgs.nerd-fonts.fira-code
  ];

  # Ptyxis (GNOME's terminal since 49) keeps its font in dconf, so this does not
  # have to be a trip through Preferences.
  #
  # `use-system-font = true` was the actual blocker: while that is set, Ptyxis
  # ignores `font-name` entirely and follows the GNOME system monospace font --
  # which is DejaVu Sans Mono and has none of the required glyphs.
  #
  # Size 10 matches what was in effect before ("Monospace 10"). Adjust the number
  # here if FiraCode reads smaller at the same point size.
  dconf.settings."org/gnome/Ptyxis" = {
    use-system-font = false;
    font-name = "FiraCode Nerd Font Mono 10";
  };
}
