{ stdenvNoCC, lib }:

stdenvNoCC.mkDerivation {
  pname = "seguiemj";
  version = "unstable";

  src = ./seguiemj.ttf;

  dontUnpack = true;
  dontBuild = true;
  dontConfigure = true;

  installPhase = ''
    runHook preInstall
    mkdir -p $out/share/fonts/truetype
    cp $src $out/share/fonts/truetype/seguiemj.ttf
    runHook postInstall
  '';

  meta = with lib; {
    description = "Segoe UI Emoji font";
    platforms = platforms.all;
  };
}
