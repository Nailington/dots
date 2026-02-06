{ stdenv, lib, autoPatchelfHook, zlib, glibc }:

stdenv.mkDerivation rec {
  pname = "damx-daemon";
  version = "0.4.6";

  # Pre-compiled PyInstaller binary from the release
  src = ../../DAMX-0.9.1/DAMX-Daemon;

  nativeBuildInputs = [ autoPatchelfHook ];
  
  buildInputs = [
    stdenv.cc.cc.lib  # libstdc++
    zlib
    glibc
  ];

  dontBuild = true;
  dontConfigure = true;

  installPhase = ''
    runHook preInstall
    install -D -m755 DAMX-Daemon $out/bin/DAMX-Daemon
    runHook postInstall
  '';

  meta = with lib; {
    description = "DAMX Daemon for Acer laptop hardware control";
    homepage = "https://github.com/PXDiv/Div-Acer-Manager-Max";
    license = licenses.gpl3;
    platforms = [ "x86_64-linux" ];
  };
}
