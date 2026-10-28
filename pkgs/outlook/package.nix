# Outlook as a launcher, not as an application.
#
# There is no Microsoft Outlook for Linux -- the "new Outlook" is the web app --
# and nixpkgs has no package: `outlook`, `outlook-for-linux`, `ms-outlook` and
# `microsoft-outlook` are all missing attributes. So this is a desktop entry that
# opens the web app in a browser, with no binary of its own.
#
# Why Chromium rather than the Firefox that system/packages.nix already installs:
# this needs an *app-mode* window -- chrome-less, no address bar or tabs, and
# with its own window class so the task manager treats it as a separate program
# instead of grouping it under the browser. Firefox dropped site-specific-browser
# support in 2021 and has no `--app=`. The remaining Firefox route is firefoxpwa,
# which re-adds it through a native connector but needs a runtime
# `firefoxpwa site install` and keeps its profile state outside Nix -- the same
# class of non-declarative bootstrap as the krew plugins. Chromium's `--app=` is
# a plain flag and works from the generation alone.
#
# The cost is a second browser engine: Chromium's closure is ~1.8G, accepted
# deliberately.
#
# The URL is the one the outlook-ew snap used, read out of its app.asar, so this
# lands on the same interface that was in use on the Ubuntu machine.
{
  lib,
  runCommand,
  makeDesktopItem,
  chromium,
}:

let
  url = "https://outlook.office.com/mail/";

  # Both halves of the window-class trick. `--class` is what Chromium sets as the
  # window's WM_CLASS; StartupWMClass below is what the task manager matches
  # against to tie that window to this launcher. With only one of them, a pinned
  # Outlook icon stays dark while a second, unpinned entry appears beside it.
  wmClass = "Outlook";

  item = makeDesktopItem {
    name = "outlook";
    desktopName = "Outlook";
    comment = "Microsoft Outlook web app";
    # The store path rather than the bare name: a desktop entry is launched by
    # the desktop environment, whose PATH is not the shell's.
    exec = "${lib.getExe chromium} --app=${url} --class=${wmClass}";
    icon = "outlook";
    startupWMClass = wmClass;
    categories = [
      "Office"
      "Network"
      "Email"
    ];
  };
in

runCommand "outlook"
  {
    meta = {
      description = "Desktop entry opening the Outlook web app as a Chromium app window";
      homepage = url;
      platforms = lib.platforms.linux;
    };
  }
  ''
    mkdir -p $out/share
    cp -r ${item}/share/applications $out/share/

    # 393x404, which fits no hicolor size bucket, so share/pixmaps -- the place
    # the icon spec keeps for exactly this. `Icon=outlook` resolves there.
    #
    # Provenance: lifted from the outlook-ew snap's meta/gui/icon.png. Kept in
    # the repository rather than fetched, because the alternatives are a 96MB
    # snap download or papirus-icon-theme at 1.1GB, both for one 361KB file.
    install -Dm644 ${./icon.png} $out/share/pixmaps/outlook.png
  ''
