{ stdenv, lib, autoPatchelfHook, fetchurl, zlib, glibc }:

stdenv.mkDerivation rec {
  pname = "damx-daemon";
  version = "0.9.1";

  src = fetchurl {
    url = "https://github.com/PXDiv/Div-Acer-Manager-Max/releases/download/v${version}/DAMX-${version}.tar.xz";
    hash = "sha256-2amtWkZh+ASPmN6p6alWo8shnrpy7AdhRGlAdc7WlIQ=";
  };

  nativeBuildInputs = [ autoPatchelfHook ];

  buildInputs = [
    stdenv.cc.cc.lib
    zlib
    glibc
  ];

  dontBuild = true;
  dontConfigure = true;

  installPhase = ''
    runHook preInstall
    install -D -m755 DAMX-Daemon/DAMX-Daemon $out/bin/DAMX-Daemon
    runHook postInstall
  '';

  meta = with lib; {
    description = "DAMX Daemon for Acer laptop hardware control";
    homepage = "https://github.com/PXDiv/Div-Acer-Manager-Max";
    license = licenses.gpl3;
    platforms = [ "x86_64-linux" ];
  };
}
