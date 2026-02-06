{ stdenv, lib, kernel, kmod }:

stdenv.mkDerivation rec {
  pname = "linuwu-sense";
  version = "25.701";

  # Source from the extracted release
  src = ../../DAMX-0.9.1/Linuwu-Sense;

  nativeBuildInputs = kernel.moduleBuildDependencies;

  makeFlags = [
    "KVER=${kernel.modDirVersion}"
    "KDIR=${kernel.dev}/lib/modules/${kernel.modDirVersion}/build"
  ];

  buildPhase = ''
    runHook preBuild
    make $makeFlags
    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall
    install -D src/linuwu_sense.ko $out/lib/modules/${kernel.modDirVersion}/extra/linuwu_sense.ko
    runHook postInstall
  '';

  meta = with lib; {
    description = "Linuwu Sense kernel driver for Acer laptop hardware control";
    homepage = "https://github.com/PXDiv/Div-Acer-Manager-Max";
    license = licenses.gpl3;
    platforms = platforms.linux;
  };
}
