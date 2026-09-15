{
  stdenvNoCC,
  lib,
  fetchurl,
  unzip,
}:

stdenvNoCC.mkDerivation rec {
  pname = "google-sans";
  version = "14.000";

  src = fetchurl {
    url = "https://github.com/googlefonts/googlesans/releases/download/v${version}/GoogleSans-v${version}.zip";
    hash = "sha256-0zjw509eq+rYaoW4ft9MxQzWVhGW2+Fz0dtBOelbPKc=";
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
    description = "Google Sans typeface";
    homepage = "https://github.com/googlefonts/googlesans";
    license = licenses.ofl;
    platforms = platforms.all;
  };
}
