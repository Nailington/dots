{ lib
, stdenvNoCC
, fetchFromGitHub
, python3
, gtk3
, libhandy
, libappindicator-gtk3
, libnotify
, usbmuxd
, libimobiledevice
, avahi
, wrapGAppsHook3
, gobject-introspection
, gdk-pixbuf
, makeDesktopItem
, copyDesktopItems
, steam-run
}:

let
  pythonEnv = python3.withPackages (ps: with ps; [
    requests
    keyring
    pygobject3
    packaging
  ]);

  desktopItem = makeDesktopItem {
    name = "althea";
    exec = "althea";
    icon = "althea";
    desktopName = "althea";
    comment = "Sideload applications to iOS/iPadOS via AltStore";
    categories = [ "Utility" ];
  };
in

stdenvNoCC.mkDerivation rec {
  pname = "althea";
  version = "altlinux-unstable-2026-06-09";

  src = fetchFromGitHub {
    owner = "vyvir";
    repo = "althea";
    rev = "215d8aaa748fe9bb0d18446ceaee242e40683719";
    hash = "sha256-GQPbdz+lLX46V8YLFXIvt06wsjufaCn4sdkzll75S9Q=";
  };

  nativeBuildInputs = [
    wrapGAppsHook3
    gobject-introspection
    copyDesktopItems
  ];

  buildInputs = [
    pythonEnv
    gtk3
    libhandy
    libappindicator-gtk3
    libnotify
    gdk-pixbuf
    usbmuxd
    libimobiledevice
    avahi
  ];

  dontBuild = true;
  dontConfigure = true;

  desktopItems = [ desktopItem ];

  installPhase = ''
    runHook preInstall

    # Install app files
    mkdir -p $out/lib/althea/resources
    cp main.py $out/lib/althea/
    cp -r resources/* $out/lib/althea/resources/

    # Install icon
    mkdir -p $out/share/icons/hicolor/256x256/apps
    cp resources/3.png $out/share/icons/hicolor/256x256/apps/althea.png

    # Patch main.py: replace direct anisette-server invocation with steam-run wrapper
    # The downloaded binary is a generic Linux ELF that needs an FHS environment on NixOS
    substituteInPlace $out/lib/althea/main.py \
      --replace-warn \
        'subprocess.run(f"{(altheapath)}/anisette-server -n 127.0.0.1 -p 6969 &", shell=True)' \
        'subprocess.run(f"${steam-run}/bin/steam-run {(altheapath)}/anisette-server -n 127.0.0.1 -p 6969 &", shell=True)'

    # Create launcher
    mkdir -p $out/bin
    cat > $out/bin/althea << EOF
#!/bin/sh
cd $out/lib/althea
exec ${pythonEnv}/bin/python3 $out/lib/althea/main.py "\$@"
EOF
    chmod +x $out/bin/althea

    runHook postInstall
  '';

  meta = with lib; {
    description = "GUI for AltServer-Linux to sideload apps onto iOS/iPadOS";
    homepage = "https://github.com/vyvir/althea";
    license = licenses.agpl3Only;
    platforms = [ "x86_64-linux" "aarch64-linux" ];
    mainProgram = "althea";
  };
}
