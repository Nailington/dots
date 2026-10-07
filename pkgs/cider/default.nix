{ stdenv
, lib
, fetchurl
, zstd
, buildFHSEnv
, writeShellScript
}:

let
  version = "4.0.17";

  ciderExtracted = stdenv.mkDerivation {
    pname = "cider-extracted";
    inherit version;

    src = fetchurl {
      url = "https://repo.cider.sh/arch/x64/cider-v${version}-linux-x64.pkg.tar.zst";
      sha256 = "sha256-ZaLMy7s5XeLLYO91d0lfjcsCDRWRgHFtM/YTLNUb6MM=";
    };

    nativeBuildInputs = [ zstd ];

    unpackPhase = ''
      mkdir -p pkg
      tar -xf $src -C pkg
    '';

    installPhase = ''
      mkdir -p $out
      cp -r pkg/usr/lib/cider/* $out/
      install -Dm644 pkg/usr/share/pixmaps/cider.png $out/share/pixmaps/cider.png
    '';

    meta = { platforms = [ "x86_64-linux" ]; };
  };

  ciderWrapper = writeShellScript "cider" ''
    # An inherited Chromium desktop ID starts a GLib file-monitor thread in
    # Electron's zygote, which must remain single-threaded to enter its sandbox.
    unset CHROME_DESKTOP
    cd ${ciderExtracted}
    exec ./Cider "$@"
  '';
in
buildFHSEnv {
  pname = "cider";
  inherit version;

  targetPkgs = pkgs: with pkgs; [
    systemd
    dbus
    cups
    cairo pango gdk-pixbuf atk gtk3
    glib nss nspr
    at-spi2-atk at-spi2-core
    libdrm libxkbcommon mesa libgbm
    libx11 libxcomposite libxdamage libxext
    libxfixes libxrandr libxcb libxcursor libxi
    alsa-lib libpulseaudio
    libGL libva vulkan-loader
    expat fontconfig freetype
    harfbuzz
    libxcrypt-legacy libnotify
  ];

  runScript = ciderWrapper;

  extraInstallCommands = ''
    mkdir -p $out/share/applications
    mkdir -p $out/share/pixmaps
    ln -s ${ciderExtracted}/share/pixmaps/cider.png $out/share/pixmaps/cider.png

    cat > $out/share/applications/cider.desktop << 'DESKTOP'
[Desktop Entry]
Type=Application
Name=Cider
StartupWMClass=Cider
Comment=A cross-platform Apple Music experience built on Vue.js and written from the ground up with performance in mind.
GenericName=Music Player
Exec=cider %U
Icon=cider
Categories=Audio;AudioVideo;Music;
MimeType=x-scheme-handler/ame;x-scheme-handler/cider;x-scheme-handler/itms;x-scheme-handler/itmss;x-scheme-handler/musics;x-scheme-handler/music;x-scheme-handler/itunes;

Actions=PlayPause;Next;Previous;Stop

[Desktop Action PlayPause]
Name=Play-Pause
Exec=dbus-send --print-reply --dest=org.mpris.MediaPlayer2.cider /org/mpris/MediaPlayer2 org.mpris.MediaPlayer2.Player.PlayPause

[Desktop Action Next]
Name=Next
Exec=dbus-send --print-reply --dest=org.mpris.MediaPlayer2.cider /org/mpris/MediaPlayer2 org.mpris.MediaPlayer2.Player.Next

[Desktop Action Previous]
Name=Previous
Exec=dbus-send --print-reply --dest=org.mpris.MediaPlayer2.cider /org/mpris/MediaPlayer2 org.mpris.MediaPlayer2.Player.Previous

[Desktop Action Stop]
Name=Stop
Exec=dbus-send --print-reply --dest=org.mpris.MediaPlayer2.cider /org/mpris/MediaPlayer2 org.mpris.MediaPlayer2.Player.Stop
DESKTOP
  '';

  meta = with lib; {
    description = "A cross-platform Apple Music experience";
    homepage = "https://cider.sh";
    license = licenses.unfree;
    platforms = [ "x86_64-linux" ];
    mainProgram = "cider";
    maintainers = [ ];
  };
}
