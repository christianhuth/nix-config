# KDE Plasma, through plasma-manager (the module comes in via
# home-manager.sharedModules in flake.nix).
#
# For now this declares the one panel and nothing else: it is Plasma's default
# panel, written out, so that the launchers in its task manager are configured
# here instead of pinned by hand.
#
# Careful, as soon as `panels` is set plasma-manager OWNS the panel layout: on
# every change it deletes ~/.config/plasma-org.kde.plasma.desktop-appletsrc and
# rebuilds all panels from this list. A widget added or a panel moved in the GUI
# is gone after the next change here -- and that file also holds the wallpaper
# and the desktop's folder-view settings, which are reset along with it. Both
# were still at their defaults when this was introduced. A wallpaper that should
# survive belongs in `programs.plasma.workspace.wallpaper`.
#
# The layout is applied by a login script, not by the switch itself: after
# `nixos-rebuild switch`, log out and back in to see a change.
{ ... }:

{
  programs.plasma = {
    enable = true;

    panels = [
      {
        location = "bottom";
        floating = true;
        height = 46;

        widgets = [
          "org.kde.plasma.kickoff"
          "org.kde.plasma.pager"
          {
            iconTasks.launchers = [
              # `applications:<id>.desktop`, looked up in XDG_DATA_DIRS at
              # runtime. What pinning by drag and drop writes instead is
              # file:///nix/store/<hash>-system-path/share/applications/...,
              # a path into one generation that turns into a dead icon once
              # that generation is garbage-collected.
              "preferred://filemanager" # Dolphin, or whatever is set as default
              "applications:gimp.desktop"
              "applications:spotify.desktop"
              "preferred://browser" # Firefox, see system/packages.nix
              "applications:thunderbird.desktop"
              "applications:outlook-ew.desktop"
              "applications:signal.desktop"
              "applications:teams-for-linux.desktop"
              "applications:org.kde.konsole.desktop"
              "applications:termius-app.desktop"
              "applications:headlamp.desktop"
              "applications:codium.desktop"
            ];
          }
          "org.kde.plasma.marginsseparator"
          "org.kde.plasma.systemtray"
          "org.kde.plasma.digitalclock"
          "org.kde.plasma.showdesktop"
        ];
      }
    ];
  };
}
