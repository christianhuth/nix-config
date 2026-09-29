{ config, lib, ... }:

let
  # Evaluated per configuration, not at runtime: home/root.nix sets
  # home.username = "root", so the two generations differ in exactly this colour
  # and share the rest of the file.
  #
  # This detour is necessary because starship cannot branch a style on the current
  # UID. Only the `username` module has style_user/style_root; the opening cap, the
  # $os module and the separator after the username are plain static styles, which
  # is why a root shell kept an orange icon and an orange trailing triangle around
  # a red username.
  isRoot = config.home.username == "root";
  accent = if isRoot then "color_red" else "color_orange";
in
{
  programs.starship = {
    enable = true; # installs starship itself

    # enableBashIntegration defaults to true. The module injects
    #   eval "$(starship init bash --print-full-init)"
    # into the generated ~/.bashrc with lib.mkOrder 1900, i.e. after everything
    # home/bash.nix sets at the default 1000 -- which is why the old PS1 was
    # removed there rather than left as dead code.

    # Powerline separators and Nerd Font icons throughout, so this needs a Nerd
    # Font selected in the terminal -- see home/fonts.nix.
    #
    # The preset also brings `username.show_always = true`, so the user appears
    # without any extra setting here.
    presets = [ "gruvbox-rainbow" ];

    settings = {
      # The preset defines its own top-level `format` as an explicit list of
      # modules, and a module not named there renders nowhere however it is
      # configured -- so placing $kubernetes means overriding the format.
      #
      # `right_format` is not an option: in bash starship only draws a right
      # prompt when ble.sh is attached, and plain readline has none at all.
      #
      # Three changes against the preset:
      #   * the leading cap and the separator after $username use `accent`, so the
      #     whole first segment turns red for root
      #   * a $kubernetes segment in color_purple between git and the languages
      #     (purple, color_green and color_red are the palette colours the preset
      #     leaves unused)
      #   * $time dropped, with its closing cap moved from color_bg1 to color_bg3
      #
      # Everything else is the preset's own module list verbatim -- note it has no
      # $cmd_duration, unlike catppuccin-powerline. Glyphs are the preset's:
      # U+E0B6 opening, U+E0B0 separator, U+E0B4 closing.
      format = lib.concatStrings [
        "[](${accent})"
        "$os"
        "$username"
        "[](bg:color_yellow fg:${accent})"
        "$directory"
        "[](fg:color_yellow bg:color_aqua)"
        "$git_branch"
        "$git_status"
        "[](fg:color_aqua bg:color_purple)"
        "$kubernetes"
        "[](fg:color_purple bg:color_blue)"
        "$c$cpp$rust$golang$nodejs$bun$php$java$kotlin$haskell$python"
        "[](fg:color_blue bg:color_bg3)"
        "$docker_context"
        "$conda"
        "$pixi"
        "[ ](fg:color_bg3)"
        "$line_break"
        "$character"
      ];

      # The distro icon sits inside the first segment, so its background has to
      # follow the accent too -- otherwise it stays an orange block in front of a
      # red username.
      os.style = "bg:${accent} fg:color_fg0";

      username = {
        style_user = "bg:${accent} fg:color_fg0";

        # Kept red independently of `accent`, so a shell that runs *this* user's
        # configuration while being root -- `sudo -s` keeps HOME on Ubuntu's
        # default sudoers -- still marks itself. The surrounding segment stays
        # orange in that case; `sudo -i` is the clean way in.
        style_root = "bg:color_red fg:color_fg0";
      };

      kubernetes = {
        # starship ships this module disabled, and no preset turns it on --
        # presets only swap symbols and colours. gruvbox-rainbow does not mention
        # kubernetes at all, so the symbol stays the stock "☸ ".
        disabled = false;

        # Follows the preset's own pattern: `style` carries only the background,
        # the foreground is set inside `format`.
        style = "bg:color_purple";

        # Indented string on purpose: in a "..." string Nix would eat the
        # backslashes of \( and \), which starship needs for literal parentheses
        # around the namespace.
        format = ''[[ $symbol$context( \($namespace\)) ](fg:color_fg0 bg:color_purple)]($style)'';
      };

      # The preset leaves truncate_to_repo at its default of true, which inside a
      # git repository collapses the path to just the repository name. This shows
      # the last three components everywhere instead.
      directory.truncate_to_repo = false;

      # Note: no git_branch.symbol override. The preset sets its own Nerd Font
      # glyph, and `settings` wins over `presets` in the merge, so an override
      # would blank it out.
      #
      # $time is simply absent from the format above; the module itself is left as
      # the preset configures it.
    };
  };
}
