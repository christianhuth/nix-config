# Outlook, from the `outlook-ew` snap.
#
# There is no Microsoft Outlook for Linux: the "new Outlook" is the web app, and
# nixpkgs has no package for it either -- `outlook`, `outlook-for-linux`,
# `ms-outlook` and `microsoft-outlook` are all missing attributes. What this
# packages is the same unofficial Electron wrapper (publisher "Francisco
# Martins") that was already installed as a snap on the Ubuntu machine, so the
# application is the one that was there, not a substitute.
#
# Source is the snap, because there is no other: no public source repository
# exists under that name, and the snap store is where the author publishes. That
# is better than it sounds for reproducibility -- snap downloads are pinned by
# *revision* and revisions are immutable, so unlike pkgs/termius/package.nix
# (whose vendor URL moved and broke the build) this URL keeps resolving. nixpkgs
# fetches its own Termius the same way.
#
# Two things worth being clear about:
#
#   * This is an opaque third-party binary wrapping a webmail client, repackaged
#     by us and not reviewed by nixpkgs. Same category as the Termius .deb.
#   * The snap runs under snapd's *strict* confinement. A Nix build does not --
#     it runs with the user's full privileges. Moving it here is a real
#     reduction in isolation, traded for having it in the generation.
#
# To update: read version, revision and download_sha512 from
#   curl -H 'X-Ubuntu-Series: 16' \
#     'https://api.snapcraft.io/api/v1/snaps/details/outlook-ew?fields=version,revision,download_sha512'
# and convert the digest with `nix hash convert --hash-algo sha512 --to sri <hex>`.
{
  lib,
  stdenv,
  fetchurl,
  squashfsTools,
  autoPatchelfHook,
  makeWrapper,
  wrapGAppsHook3,
  alsa-lib,
  at-spi2-atk,
  at-spi2-core,
  atk,
  cairo,
  cups,
  dbus,
  expat,
  glib,
  gtk3,
  libgbm,
  libxkbcommon,
  nspr,
  nss,
  pango,
  udev,
  xdg-utils,
  libx11,
  libxcb,
  libxcomposite,
  libxdamage,
  libxext,
  libxfixes,
  libxrandr,
}:

stdenv.mkDerivation (finalAttrs: {
  pname = "outlook-ew";
  version = "1.0.18";

  # Revision 16. The revision, not the version, is what the URL addresses, so
  # both have to be bumped together -- see the update note above.
  src = fetchurl {
    url = "https://api.snapcraft.io/api/v1/snaps/download/POE8rxP5QfxNZsav8LoWbBUgKJ3YS5D8_16.snap";
    hash = "sha512-+HSt+unaVZTQUytSO4d5gqkCYkZBtdt8t4nR4D8xXB1fBCQPPCbxZSUXNO4uAJ8RVks15EM8ZCJoGRhoJAJ4Ug==";
  };

  nativeBuildInputs = [
    autoPatchelfHook
    squashfsTools
    makeWrapper
    wrapGAppsHook3
  ];

  # The same Electron runtime set as pkgs/termius/package.nix -- verified against
  # `patchelf --print-needed` on the unpacked binary, which lists exactly these.
  buildInputs = [
    alsa-lib
    at-spi2-atk
    at-spi2-core
    atk
    cairo
    cups
    dbus
    expat
    glib
    gtk3
    libgbm
    libxkbcommon
    nspr
    nss
    pango
    udev
    libx11
    libxcb
    libxcomposite
    libxdamage
    libxext
    libxfixes
    libxrandr
  ];

  dontBuild = true;
  dontConfigure = true;
  dontPatchELF = true;
  dontWrapGApps = true;

  unpackPhase = ''
    runHook preUnpack
    unsquashfs -no-progress -dest . "$src"
    runHook postUnpack
  '';

  installPhase = ''
    runHook preInstall

    mkdir -p $out/opt/outlook-ew

    # Everything except snapd's own scaffolding. command.sh and the desktop-*.sh
    # chain exist to set up the snap runtime ($SNAP, the gnome-platform content
    # snap) and are meaningless outside it; meta/ is snap packaging metadata, of
    # which only the icon is reused below.
    for f in *; do
      case "$f" in
        meta | snap | scripts | gnome-platform | data-dir | command.sh | desktop-*.sh) ;;
        *) cp -r "$f" $out/opt/outlook-ew/ ;;
      esac
    done

    # The snap's own entry cannot be reused as-is: its Exec is the bare name
    # `outlook-ew`, resolved through snapd's PATH, and its Icon is
    # ''${SNAP}/meta/gui/icon.png, a variable only snapd sets.
    #
    # StartupWMClass is carried over verbatim and matters: the window sets its
    # class to "Microsoft Outlook", and without this line a task manager shows a
    # second, unpinned entry next to the launcher instead of grouping them.
    mkdir -p $out/share/applications
    cat > $out/share/applications/outlook-ew.desktop <<EOF
    [Desktop Entry]
    Type=Application
    Name=Outlook
    Comment=Unofficial Electron wrapper for Microsoft Outlook, built for Linux desktop.
    Exec=$out/bin/outlook-ew %U
    Icon=outlook-ew
    Terminal=false
    Categories=Office;Network;Email;
    StartupWMClass=Microsoft Outlook
    EOF
    sed -i 's/^    //' $out/share/applications/outlook-ew.desktop

    # 393x404, so it belongs in neither a hicolor size bucket nor scalable.
    # share/pixmaps is the documented place for exactly that case, and
    # `Icon=outlook-ew` finds it there.
    install -Dm644 meta/gui/icon.png $out/share/pixmaps/outlook-ew.png

    runHook postInstall
  '';

  postFixup = ''
    makeWrapper $out/opt/outlook-ew/outlook-ew $out/bin/outlook-ew \
      "''${gappsWrapperArgs[@]}" \
      --suffix PATH : ${lib.makeBinPath [ xdg-utils ]}
  '';

  meta = {
    description = "Unofficial Electron wrapper for Microsoft Outlook";
    homepage = "https://snapcraft.io/outlook-ew";
    sourceProvenance = with lib.sourceTypes; [ binaryNativeCode ];
    license = lib.licenses.unfree;
    platforms = [ "x86_64-linux" ];
    mainProgram = "outlook-ew";
  };
})
