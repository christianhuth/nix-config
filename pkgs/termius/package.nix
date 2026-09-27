# Termius, built from the vendor's official .deb instead of nixpkgs' package.
#
# Why not `pkgs.termius`? That derivation repackages the Snap Store artifact
# (it downloads a .snap from api.snapcraft.io and unsquashfs's it), and the
# revision pinned in nixpkgs 26.05 is 9.36.2 -- several releases behind.
#
# Termius publishes an electron-updater manifest at
#   https://autoupdate.termius.com/linux/latest-linux.yml
# which gives the current version, the versioned .deb filename and a base64
# sha512. That base64 digest is already in Nix's SRI format, so `hash` below
# can be copied straight out of the manifest -- see README.md for the update
# procedure.
{
  lib,
  stdenv,
  fetchurl,
  dpkg,
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
  libsecret,
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
  pname = "termius";
  version = "10.1.0";

  src = fetchurl {
    url = "https://autoupdate.termius.com/linux/termius-app_${finalAttrs.version}_amd64.deb";
    hash = "sha512-mABJip003+zApFtqczR0f+IcF85vLMqWzqnQeoiZEXVGtjkM1MsH+kvLYXEn09XiBAseFiyQyUW8AI/b607wQQ==";
  };

  nativeBuildInputs = [
    autoPatchelfHook
    dpkg
    makeWrapper
    wrapGAppsHook3
  ];

  # Exactly the external DT_NEEDED entries of the bundled ELF files, minus what
  # stdenv already provides (libc, libstdc++, libgcc_s, the dynamic loader).
  buildInputs = [
    alsa-lib # libasound.so.2
    at-spi2-atk # libatk-bridge-2.0.so.0
    at-spi2-core # libatspi.so.0
    atk # libatk-1.0.so.0
    cairo # libcairo.so.2
    cups # libcups.so.2
    dbus # libdbus-1.so.3
    expat # libexpat.so.1
    glib # libgio/libglib/libgobject-2.0.so.0
    gtk3 # libgtk-3.so.0
    libgbm # libgbm.so.1
    libsecret # libsecret-1.so.0 -- Termius keeps credentials in the keyring
    libxkbcommon # libxkbcommon.so.0
    nspr # libnspr4.so
    nss # libnss3 / libnssutil3 / libsmime3
    pango # libpango-1.0.so.0
    libx11 # libX11.so.6
    libxcb # libxcb.so.1
    libxcomposite # libXcomposite.so.1
    libxdamage # libXdamage.so.1
    libxext # libXext.so.6
    libxfixes # libXfixes.so.3
    libxrandr # libXrandr.so.2
  ];

  # libudev is opened at runtime, not linked, so autoPatchelf needs it here.
  runtimeDependencies = [ (lib.getLib udev) ];

  dontBuild = true;
  dontConfigure = true;
  # Let autoPatchelfHook own the RPATHs instead of stdenv's fixup stripping them.
  dontPatchELF = true;
  # gappsWrapperArgs is applied by hand in postFixup, together with makeWrapper.
  dontWrapGApps = true;

  unpackPhase = ''
    runHook preUnpack
    dpkg-deb -x "$src" .
    runHook postUnpack
  '';

  installPhase = ''
    runHook preInstall

    mkdir -p $out/opt
    cp -r opt/Termius $out/opt/Termius

    # The .deb ships its own desktop entry and a full set of hicolor icons.
    # Only the Exec path has to be rewritten from /opt to the store path.
    install -Dm644 usr/share/applications/termius-app.desktop \
      $out/share/applications/termius-app.desktop
    substituteInPlace $out/share/applications/termius-app.desktop \
      --replace-fail "/opt/Termius/termius-app" "$out/bin/termius-app"

    cp -r usr/share/icons $out/share/

    # Skipped on purpose: /etc/cron.daily/termius-app, which only refreshes the
    # vendor's apt repository. Updates happen through this derivation instead.

    runHook postInstall
  '';

  postFixup = ''
    makeWrapper $out/opt/Termius/termius-app $out/bin/termius-app \
      "''${gappsWrapperArgs[@]}" \
      --suffix PATH : ${lib.makeBinPath [ xdg-utils ]}
  '';

  meta = {
    description = "Cross-platform SSH client with cloud data sync, from the official .deb";
    homepage = "https://termius.com/";
    downloadPage = "https://termius.com/linux/";
    sourceProvenance = with lib.sourceTypes; [ binaryNativeCode ];
    license = lib.licenses.unfree;
    platforms = [ "x86_64-linux" ];
    mainProgram = "termius-app";
  };
})
