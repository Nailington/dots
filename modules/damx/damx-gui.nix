{ stdenv
, lib
, buildFHSEnv
, fetchurl
, writeShellScript
, fontconfig
, freetype
, xorg
, libGL
, icu
, openssl
, zlib
, krb5
, libunwind
}:

let
  version = "0.9.1";

  damxFiles = stdenv.mkDerivation {
    pname = "damx-gui-files";
    inherit version;

    src = fetchurl {
      url = "https://github.com/PXDiv/Div-Acer-Manager-Max/releases/download/v${version}/DAMX-${version}.tar.xz";
      hash = "sha256-2amtWkZh+ASPmN6p6alWo8shnrpy7AdhRGlAdc7WlIQ=";
    };

    dontBuild = true;
    dontConfigure = true;
    dontPatchELF = true;
    dontStrip = true;

    installPhase = ''
      mkdir -p $out
      cp -r DAMX-GUI/* $out/
      chmod +x $out/DivAcerManagerMax
    '';
  };

in buildFHSEnv {
  name = "damx";
  
  targetPkgs = pkgs: [
    pkgs.stdenv.cc.cc.lib
    pkgs.fontconfig
    pkgs.freetype
    # X11 libraries
    pkgs.libx11
    pkgs.libxcursor
    pkgs.libxi
    pkgs.libxrandr
    pkgs.libxext
    pkgs.libxrender
    pkgs.libxfixes
    pkgs.libice
    pkgs.libsm
    pkgs.libxtst
    pkgs.libxcomposite
    pkgs.libxdamage
    pkgs.libxcb
    # Graphics
    pkgs.libGL
    pkgs.mesa
    # .NET / System
    pkgs.icu
    pkgs.openssl
    pkgs.zlib
    pkgs.krb5
    pkgs.libunwind
    # GTK / UI
    pkgs.glib
    pkgs.gtk3
    pkgs.pango
    pkgs.cairo
    pkgs.gdk-pixbuf
    pkgs.atk
    pkgs.harfbuzz
    pkgs.libdrm
    pkgs.expat
  ];
  
  runScript = writeShellScript "damx-wrapper" ''
    exec ${damxFiles}/DivAcerManagerMax "$@"
  '';
  
  extraInstallCommands = ''
    mkdir -p $out/share/applications
    mkdir -p $out/share/icons/hicolor/256x256/apps
    
    cp ${damxFiles}/icon.png $out/share/icons/hicolor/256x256/apps/damx.png || true
    
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
  '';
  
  meta = with lib; {
    description = "DAMX GUI - Acer laptop control application (NitroSense/PredatorSense for Linux)";
    homepage = "https://github.com/PXDiv/Div-Acer-Manager-Max";
    license = licenses.gpl3;
    platforms = [ "x86_64-linux" ];
    mainProgram = "damx";
  };
}
