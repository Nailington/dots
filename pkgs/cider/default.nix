{ stdenv
, lib
, fetchurl
, zstd
, buildFHSEnv
, writeShellScript
}:

let
  version = "3.1.8";

  ciderExtracted = stdenv.mkDerivation {
    pname = "cider-extracted";
    inherit version;

    src = fetchurl {
      url = "https://repo.cider.sh/arch/cider-v${version}-linux-x64.pkg.tar.zst";
      sha256 = "sha256-u8Ax2NqKxHhmzmm4eGUi6XpfPXHy6FndujtplnUfze4=";
    };

    nativeBuildInputs = [ zstd ];

    unpackPhase = ''
      mkdir -p pkg
      tar -xf $src -C pkg
    '';

    installPhase = ''
      mkdir -p $out
      cp -r pkg/usr/lib/cider/* $out/
    '';

    meta = { platforms = [ "x86_64-linux" ]; };
  };

  ciderWrapper = writeShellScript "cider" ''
    cd ${ciderExtracted}
    exec ./Cider "$@"
  '';
in
buildFHSEnv {
  name = "cider";

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
  ];

  runScript = ciderWrapper;

  extraInstallCommands = ''
    mkdir -p $out/share/applications

    cat > $out/share/applications/cider.desktop << 'DESKTOP'
[Desktop Entry]
Type=Application
Name=Cider
StartupWMClass=cider
Comment=A cross-platform Apple Music experience built on Vue.js and written from the ground up with performance in mind.
GenericName=Music Player
Exec=cider %U
Icon=cider
Categories=Audio;AudioVideo;
MimeType=x-scheme-handler/ame;x-scheme-handler/cider;x-scheme-handler/itms;x-scheme-handler/itmss;x-scheme-handler/musics;x-scheme-handler/music;

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
