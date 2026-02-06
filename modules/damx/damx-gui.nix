{ stdenv
, lib
, autoPatchelfHook
, makeWrapper
, fontconfig
, freetype
, xorg
, libGL
, icu
, openssl
, zlib
, glibc
}:

stdenv.mkDerivation rec {
  pname = "damx-gui";
  version = "0.9.1";

  # Pre-compiled .NET Avalonia binary from the release
  src = ../../DAMX-0.9.1/DAMX-GUI;

  nativeBuildInputs = [ 
    autoPatchelfHook 
    makeWrapper 
  ];
  
  buildInputs = [
    stdenv.cc.cc.lib  # libstdc++
    fontconfig
    freetype
    xorg.libX11
    xorg.libXcursor
    xorg.libXi
    xorg.libXrandr
    libGL
    icu
    openssl
    zlib
    glibc
  ];

  dontBuild = true;
  dontConfigure = true;

  installPhase = ''
    runHook preInstall
    
    mkdir -p $out/bin
    mkdir -p $out/share/applications
    mkdir -p $out/share/icons/hicolor/256x256/apps
    
    # Install the binary
    install -D -m755 DivAcerManagerMax $out/lib/damx/DivAcerManagerMax
    
    # Install icons
    install -D -m644 icon.png $out/share/icons/hicolor/256x256/apps/damx.png
    
    # Create wrapper script
    makeWrapper $out/lib/damx/DivAcerManagerMax $out/bin/damx \
      --prefix LD_LIBRARY_PATH : "${lib.makeLibraryPath buildInputs}"
    
    # Create desktop entry
    cat > $out/share/applications/damx.desktop << EOF
    [Desktop Entry]
    Name=DAMX
    Comment=Div Acer Manager Max - Acer Laptop Control
    Exec=$out/bin/damx
    Icon=damx
    Type=Application
    Categories=System;Settings;HardwareSettings;
    Keywords=acer;nitro;predator;fan;cooling;
    EOF
    
    runHook postInstall
  '';

  meta = with lib; {
    description = "DAMX GUI - Acer laptop control application (NitroSense/PredatorSense for Linux)";
    homepage = "https://github.com/PXDiv/Div-Acer-Manager-Max";
    license = licenses.gpl3;
    platforms = [ "x86_64-linux" ];
    mainProgram = "damx";
  };
}
