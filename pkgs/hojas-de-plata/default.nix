{ stdenvNoCC, lib }:

stdenvNoCC.mkDerivation {
  pname = "hojas-de-plata";
  version = "0";

  src = ./HojasDePlata-M5We.ttf;

  dontUnpack = true;
  dontBuild = true;
  dontConfigure = true;

  installPhase = ''
    runHook preInstall
    mkdir -p $out/share/fonts/truetype
    cp $src $out/share/fonts/truetype/HojasDePlata-M5We.ttf
    runHook postInstall
  '';

  meta = with lib; {
    description = "Hojas De Plata typeface";
    platforms = platforms.all;
  };
}
