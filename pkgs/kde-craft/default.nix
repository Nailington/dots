# KDE Craft cannot live in the Nix store: it is a self-updating, writable
# prefix (CraftRoot) that clones sources, builds them, and keeps a Python
# venv at $CRAFT_ROOT/etc/virtualenv/3. This package is an FHS sandbox
# plus wrappers so that environment can run on NixOS.
#
#   craft-setup            bootstrap ~/CraftRoot (or $CRAFT_ROOT)
#   craft-shell            source craftenv.sh inside the sandbox
#   craft <pkg>            build/install a blueprint
#   nix develop .#craft    same as craft-shell
#
# https://community.kde.org/Craft
{
  lib,
  stdenv,
  writeShellApplication,
  writeTextFile,
  runCommand,
  buildFHSEnv,
  symlinkJoin,
  python312,
  cacert,
  ...
}@pkgs:

let
  python = python312.withPackages (
    ps: with ps; [
      pip
      setuptools
      wheel
      virtualenv
      requests
      pyyaml
      lxml
      packaging
      certifi
      tomli
    ]
  );

  support = runCommand "kde-craft-support" { } ''
    mkdir -p $out/bin $out/lib/kde-craft
    cp ${./entry.sh} $out/bin/kde-craft-entry
    cp ${./bootstrap.py} $out/lib/kde-craft/bootstrap.py
    chmod +x $out/bin/kde-craft-entry $out/lib/kde-craft/bootstrap.py
    # Inner commands so nix develop / craft-shell do not nest another FHS.
    for pair in craft:craft craft-setup:setup craft-shell:shell craft-run:run; do
      name="''${pair%%:*}"
      verb="''${pair##*:}"
      printf '%s\n' '#!/usr/bin/env bash' "exec /usr/bin/kde-craft-entry $verb \"\$@\"" > "$out/bin/$name"
      chmod +x "$out/bin/$name"
    done
  '';

  # Host tools + libraries Craft / Qt / KDE look for in FHS locations.
  # Do *not* add nixpkgs Qt or KDE frameworks — Craft builds or caches those
  # into CraftRoot and CMake will pick up the wrong prefix if both exist.
  fhsTargetPkgs =
    p: with p; [
      support
      python
      python312
      cacert

      # toolchain — use *wrapped* gcc/binutils only. gcc.cc (unwrapped) also
      # ships /usr/bin/gcc; FHS ignoreCollisions then leaves the raw compiler
      # on PATH, and Nix's ld cannot find glibc's Scrt1.o / crti.o.
      stdenv.cc
      stdenv.cc.libc
      stdenv.cc.cc.lib
      gcc
      binutils
      gnumake
      cmake
      ninja
      meson
      pkg-config
      pkgconf
      autoconf
      automake
      libtool
      autoconf-archive
      bison
      flex
      gperf
      gnum4
      gettext
      intltool
      nasm
      yasm
      ccache
      patchelf
      llvmPackages.clang
      llvmPackages.libclang
      llvmPackages.llvm
      lld

      # vcs / fetch
      git
      git-lfs
      openssh
      curl
      wget
      rsync
      gnupg

      # archive / text
      unzip
      zip
      p7zip
      xz
      zstd
      bzip2
      gzip
      which
      file
      patch
      diffutils
      findutils
      gnused
      gnugrep
      gawk
      coreutils
      util-linux
      procps
      hostname
      less
      nano
      strace
      gdb
      perl
      gnutar
      shared-mime-info
      desktop-file-utils
      appstream
      itstool
      xmlto
      docbook_xml_dtd_45
      docbook-xsl-nons
      xxhash

      # crypto / compression / db
      openssl
      zlib
      lz4
      libxml2
      libxslt
      icu
      sqlite
      libffi
      readline
      ncurses
      expat
      libcap
      acl
      attr
      linux-pam
      krb5
      libsecret
      libgcrypt
      libgpg-error
      libxcrypt

      # image / font / text
      fontconfig
      freetype
      harfbuzz
      cairo
      pango
      gdk-pixbuf
      libpng
      libjpeg
      libtiff
      libwebp
      lcms2
      fribidi
      graphite2

      # glib / gtk (Qt linux-requirements + accessibility)
      glib
      gtk3
      atk
      at-spi2-core
      at-spi2-atk
      dbus
      systemd
      udev
      cups
      avahi

      # X11 / xcb — https://doc.qt.io/qt-6/linux-requirements.html
      libX11
      libXext
      libXrender
      libXi
      libXcursor
      libXrandr
      libXfixes
      libXdamage
      libXcomposite
      libXinerama
      libXt
      libXtst
      libSM
      libICE
      libXxf86vm
      libxcb
      xcbutil
      xcbutilimage
      xcbutilkeysyms
      xcbutilrenderutil
      xcbutilwm
      xcb-util-cursor
      libxkbcommon
      xorgproto
      libxshmfence

      # wayland / gpu
      wayland
      wayland-protocols
      wayland-scanner
      libdecor
      libdrm
      libgbm
      mesa
      libGL
      libglvnd
      libva
      vulkan-loader
      vulkan-headers
      libinput
      libepoxy

      # audio
      alsa-lib
      libpulseaudio
      pipewire
      libjack2

      # runtime helpers for built apps
      nss
      nspr
      pciutils
      linuxHeaders
      hicolor-icon-theme
      adwaita-icon-theme
    ];

  fhs = buildFHSEnv {
    name = "kde-craft-env";
    targetPkgs = fhsTargetPkgs;
    extraOutputsToInstall = [
      "dev"
      "bin"
      "man"
    ];
    runScript = "kde-craft-entry";
    profile = ''
      export SSL_CERT_FILE=${cacert}/etc/ssl/certs/ca-bundle.crt
      export NIX_SSL_CERT_FILE="$SSL_CERT_FILE"
      export REQUESTS_CA_BUNDLE="$SSL_CERT_FILE"
      export CRAFT_PYTHON_BIN=/usr/bin/python3
      export CRAFT_ROOT="''${CRAFT_ROOT:-$HOME/CraftRoot}"

      # Activate cc-wrapper / bintools-wrapper so they inject -B<glibc>/lib
      # (startup objects). Without this, meson dies with "cannot find Scrt1.o".
      export NIX_CC_WRAPPER_TARGET_HOST_${stdenv.cc.suffixSalt}=1
      export NIX_BINTOOLS_WRAPPER_TARGET_HOST_${stdenv.cc.suffixSalt}=1
    '';
  };

  mkWrapper =
    name: verb:
    writeShellApplication {
      inherit name;
      text = ''
        exec ${fhs}/bin/kde-craft-env ${verb} "$@"
      '';
    };

  craft = mkWrapper "craft" "craft";
  craft-shell = mkWrapper "craft-shell" "shell";
  craft-setup = mkWrapper "craft-setup" "setup";
  craft-run = mkWrapper "craft-run" "run";

  readme = writeTextFile {
    name = "kde-craft-readme";
    destination = "/share/doc/kde-craft/README";
    text = ''
      KDE Craft on NixOS
      ==================

      Craft is not a Nix package — it owns a writable prefix (default
      ~/CraftRoot) and a Python venv. These wrappers enter an FHS sandbox
      so that prefix can compile and run on NixOS.

        craft-setup          first-time install
        craft-shell          interactive env (also: nix develop .#craft)
        craft kate           build Kate + dependencies
        craft-run kate       run a Craft-built binary

      Set CRAFT_ROOT to put the prefix somewhere else (SSD, extra disk).
      After a Nix Python upgrade, if the venv breaks:

        rm -rf "$CRAFT_ROOT/etc/virtualenv"
        craft craft

      https://community.kde.org/Craft
    '';
  };
in
symlinkJoin {
  name = "kde-craft";
  paths = [
    craft
    craft-shell
    craft-setup
    craft-run
    readme
  ];

  passthru = {
    inherit fhs python support;
    devShell = fhs.env;
  };

  meta = with lib; {
    description = "FHS sandbox and wrappers for KDE Craft on NixOS";
    homepage = "https://community.kde.org/Craft";
    license = licenses.mit;
    platforms = [ "x86_64-linux" ];
    mainProgram = "craft";
  };
}
