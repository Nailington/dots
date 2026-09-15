{
  stdenvNoCC,
  lib,
  fetchurl,
  unzip,
}:

stdenvNoCC.mkDerivation rec {
  pname = "google-sans-flex";
  version = "4.007";

  src = fetchurl {
    url = "https://github.com/googlefonts/googlesans-flex/releases/download/v${version}/GoogleSansFlex-v${version}.zip";
    hash = "sha256-tzdRMb/8Xqrr62XGlSm6EOf3qZYrkTSI9u81xDLOGck=";
  };

  nativeBuildInputs = [ unzip ];

  dontBuild = true;
  dontConfigure = true;

  unpackPhase = ''
    runHook preUnpack
    unzip -q $src
    runHook postUnpack
  '';

  installPhase = ''
    runHook preInstall
    mkdir -p $out/share/fonts/truetype $out/share/fonts/opentype
    find . -iname '*.ttf' -exec install -Dm644 {} -t $out/share/fonts/truetype \;
    find . -iname '*.otf' -exec install -Dm644 {} -t $out/share/fonts/opentype \;
    find . -iname '*.ttc' -exec install -Dm644 {} -t $out/share/fonts/truetype \;
    runHook postInstall
  '';

  meta = with lib; {
    description = "Google Sans Flex typeface";
    homepage = "https://github.com/googlefonts/googlesans-flex";
    license = licenses.ofl;
    platforms = platforms.all;
  };
}
