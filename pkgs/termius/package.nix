# Termius, built from the vendor's official .deb instead of nixpkgs' package.
#
# Why not `pkgs.termius`? That derivation repackages the Snap Store artifact
# (it downloads a .snap from api.snapcraft.io and unsquashfs's it), and the
# revision pinned in nixpkgs 26.05 is 9.36.2 -- several releases behind.
#
# Termius no longer offers a versioned download, which is why `src` below points
# at an unversioned URL. Measured 2026-10-17, after a NixOS build failed with
# "cannot download termius-app_10.1.0_amd64.deb from any mirror":
#
#   autoupdate.termius.com/linux/termius-app_10.1.0_amd64.deb   404
#   autoupdate.termius.com/linux/termius-app_10.1.3_amd64.deb   404
#   autoupdate.termius.com/linux/termius-app_10.2.1_amd64.deb   404
#   download.termius.com/linux/termius-app_10.2.1_amd64.deb     404
#   download.termius.com/linux/Termius.deb                      200
#
# The electron-updater manifests at autoupdate.termius.com/linux/latest-linux.yml
# and download.termius.com/linux/latest-linux.yml both still advertise 10.1.3,
# while the file actually served is 10.2.1 -- so the manifest is no longer a
# usable source for either the version or the hash, and the old update procedure
# in README.md does not work any more.
#
# What this costs: the URL is a moving target, so the pinned hash stops matching
# on every Termius release and the build then fails with
#
#   hash mismatch in fixed-output derivation ...
#     specified: sha512-OFI4...
#     got:       sha512-<new>
#
# Copy the `got:` value in here. That is strictly better than the 404 this
# replaces -- the error hands you the answer -- but it does mean an old checkout
# of this repository cannot be rebuilt from scratch once a new release is out.
# The `version` below is therefore a label read out of the .deb's control file
# (`dpkg-deb --info`), not something that selects what gets downloaded.
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
  version = "10.2.1";

  src = fetchurl {
    # Unversioned on purpose -- see the top of this file. Deliberately NOT
    # interpolating `version`: that would suggest the URL selects a version.
    url = "https://download.termius.com/linux/Termius.deb";
    hash = "sha512-OFI4vhmbL55FHC23G59RPXiRCvZvDysdkEcgZx8YkUUjDGNefk8JvUsYW90VQb1pCGszvzOpoK9UrNW2hIpDyw==";
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
