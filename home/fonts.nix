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

    # Document fonts, for the LibreOffice in home/default.nix. These are the
    # free, *metrically compatible* substitutes -- same advance widths as the
    # Microsoft originals, so a document keeps its line and page breaks even
    # though the glyphs differ slightly:
    #
    #   carlito         <-> Calibri   (Word's default since 2007)
    #   caladea         <-> Cambria
    #   liberation_ttf  <-> Arial, Times New Roman, Courier New
    #
    # Needed because pkgs.libreoffice ships no fonts at all, which is easy to
    # assume otherwise: it contains zero .ttf files.
    #
    # The genuine Microsoft faces would be pkgs.corefonts (Arial, Times, Courier
    # and friends; unfree, accepts an EULA). There is no `vistafonts` attribute
    # in 26.05, so Calibri and Cambria themselves are not available this way at
    # all -- the metric substitutes above are the answer, not a fallback.
    pkgs.carlito
    pkgs.caladea
    pkgs.liberation_ttf
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
