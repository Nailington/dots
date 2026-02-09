{ stdenv
, lib
, fetchurl
}:

stdenv.mkDerivation rec {
  pname = "posys-cursor-scalable";
  version = "1.3";

  srcs = [
    (fetchurl {
      url = "https://github.com/Morxemplum/posys-cursor-scalable/releases/download/v${version}/hyprcursor_white_v${version}.tar.gz";
      sha256 = "sha256-oSsCYqgear3A2SafJhwG4uDCBD4JUb1lBlzYFtxIDoY=";
      name = "hyprcursor_white.tar.gz";
    })
    (fetchurl {
      url = "https://github.com/Morxemplum/posys-cursor-scalable/releases/download/v${version}/hyprcursor_black_v${version}.tar.gz";
      sha256 = "sha256-/NFhpZ6Gm9sWN8SOvbne3GXaG1iKjmQTQj7bnlF5JQI=";
      name = "hyprcursor_black.tar.gz";
    })
    (fetchurl {
      url = "https://github.com/Morxemplum/posys-cursor-scalable/releases/download/v${version}/hyprcursor_mono_v${version}.tar.gz";
      sha256 = "sha256-by8HJLNBCN9oNJDZegOUQEbgRfe5EOTDJod8Ew0CiRo=";
      name = "hyprcursor_mono.tar.gz";
    })
    (fetchurl {
      url = "https://github.com/Morxemplum/posys-cursor-scalable/releases/download/v${version}/hyprcursor_mono_black_v${version}.tar.gz";
      sha256 = "sha256-7Pw44roBiev/lKC/KfyNhVA08Vj7zLfMyt0MNwXponQ=";
      name = "hyprcursor_mono_black.tar.gz";
    })
  ];

  sourceRoot = ".";

  dontBuild = true;
  dontConfigure = true;

  unpackPhase = ''
    runHook preUnpack
    
    for src in $srcs; do
      tar xzf "$src"
    done
    
    runHook postUnpack
  '';

  installPhase = ''
    runHook preInstall
    
    mkdir -p $out/share/icons
    
    # Install all hyprcursor themes
    for theme in theme_Posys-Cursor-Scalable*; do
      if [ -d "$theme" ]; then
        cp -r "$theme" $out/share/icons/
      fi
    done
    
    runHook postInstall
  '';

  meta = with lib; {
    description = "Posy's Cursor theme made scalable with SVGs for Hyprland (hyprcursor)";
    homepage = "https://github.com/Morxemplum/posys-cursor-scalable";
    license = licenses.mit;
    platforms = platforms.linux;
    maintainers = [ ];
  };
}
