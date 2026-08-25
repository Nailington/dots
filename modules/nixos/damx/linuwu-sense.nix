{ stdenv, lib, fetchurl, kernel, kmod }:

stdenv.mkDerivation rec {
  pname = "linuwu-sense";
  version = "25.701";
  damxVersion = "0.9.1";

  src = fetchurl {
    url = "https://github.com/PXDiv/Div-Acer-Manager-Max/releases/download/v${damxVersion}/DAMX-${damxVersion}.tar.xz";
    hash = "sha256-2amtWkZh+ASPmN6p6alWo8shnrpy7AdhRGlAdc7WlIQ=";
  };

  nativeBuildInputs = kernel.moduleBuildDependencies;

  # linux 7.2 dropped the strncpy prototype; same change as
  # https://github.com/0x7375646F/Linuwu-Sense/pull/128
  postPatch = ''
    substituteInPlace Linuwu-Sense/src/linuwu_sense.c \
      --replace-fail '#include <linux/delay.h>' $'#include <linux/delay.h>\n#include <linux/device.h>' \
      --replace-fail 'strncpy(input, buf, len);' 'strscpy(input, buf, sizeof(input));' \
      --replace-fail 'strncpy(input_buf, buf, len);' 'strscpy(input_buf, buf, sizeof(input_buf));' \
      --replace-fail 'strncpy(str_buf, buf, len);' 'strscpy(str_buf, buf, sizeof(str_buf));'
  '';

  makeFlags = [
    "KVER=${kernel.modDirVersion}"
    "KDIR=${kernel.dev}/lib/modules/${kernel.modDirVersion}/build"
  ];

  buildPhase = ''
    runHook preBuild
    make -C Linuwu-Sense $makeFlags
    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall
    install -D Linuwu-Sense/src/linuwu_sense.ko \
      $out/lib/modules/${kernel.modDirVersion}/extra/linuwu_sense.ko
    runHook postInstall
  '';

  meta = with lib; {
    description = "Linuwu Sense kernel driver for Acer laptop hardware control";
    homepage = "https://github.com/PXDiv/Div-Acer-Manager-Max";
    license = licenses.gpl3;
    platforms = platforms.linux;
  };
}
