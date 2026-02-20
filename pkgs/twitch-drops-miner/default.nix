# Twitch Drops Miner - packaged from dev-build AppImage per NixOS Wiki
# https://wiki.nixos.org/wiki/Appimage
# https://github.com/DevilXD/TwitchDropsMiner/releases/tag/dev-build
# Wrapper copies to writable dir on first run (app writes to its installation dir)

{ lib
, appimageTools
, fetchurl
, runCommand
, unzip
, writeShellScript
}:

let
  pname = "twitch-drops-miner";
  version = "dev-build";

  # AppImage is shipped inside a zip on the dev-build release
  zip = fetchurl {
    url = "https://github.com/DevilXD/TwitchDropsMiner/releases/download/dev-build/Twitch.Drops.Miner.Linux.AppImage-x86_64.zip";
    hash = "sha256-Nm0BZxnC38U/Nu1opog2+2/RYCqJg+e+l887MfDez7M=";
  };

  # Extract AppImage from zip (zip contains single .AppImage file)
  appimageSrc = runCommand "${pname}-appimage" {
    inherit zip;
    nativeBuildInputs = [ unzip ];
  } ''
    unzip $zip -d extracted
    appimage=$(find extracted -name "*.AppImage" -type f | head -1)
    if [ -z "$appimage" ]; then
      echo "No AppImage found in zip. Contents:"
      find extracted -type f
      exit 1
    fi
    mkdir -p $out
    cp "$appimage" $out/twitch-drops-miner.AppImage
  '';

  # Extract AppImage contents (read-only in store)
  extracted = appimageTools.extract {
    inherit pname version;
    src = "${appimageSrc}/twitch-drops-miner.AppImage";
  };

  # Wrapper script: copy to writable dir on first run (app writes to its installation dir)
  # runScript is pasted after exec, so we need a script path - not inline shell
  runScript = writeShellScript "twitch-drops-miner-run" ''
    TDM_DATA="''${XDG_DATA_HOME:-$HOME/.local/share}/twitch-drops-miner"
    mkdir -p "$TDM_DATA"
    if [ ! -f "$TDM_DATA/usr/src/main.py" ]; then
      cp -r ${extracted}/* "$TDM_DATA/"
    fi
    chmod -R u+w "$TDM_DATA"
    # Remove app's conflicting system libs - use FHS env libs (keeps Python site-packages)
    rm -rf "$TDM_DATA/usr/lib/x86_64-linux-gnu"
    exec appimage-exec.sh -w "$TDM_DATA" -- "$@"
  '';
in
appimageTools.wrapAppImage {
  inherit pname version;
  src = extracted;
  runScript = runScript;

  extraPkgs = pkgs: with pkgs; [ tk tcl libffi ];

  extraInstallCommands = ''
    if [ -d $out/share/applications ]; then
      for f in $out/share/applications/*.desktop; do
        [ -f "$f" ] && substituteInPlace "$f" --replace 'Exec=AppRun' 'Exec=twitch-drops-miner' || true
      done
    fi
  '';

  meta = with lib; {
    description = "Automatically farm Twitch drops without actively watching streams";
    homepage = "https://github.com/DevilXD/TwitchDropsMiner";
    license = licenses.mit;
    platforms = [ "x86_64-linux" ];
    mainProgram = "twitch-drops-miner";
    sourceProvenance = with lib.sourceTypes; [ binaryNativeCode ];
  };
}
