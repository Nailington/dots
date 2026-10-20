{
  stdenv,
  lib,
  fetchurl,
  unzip,
  buildFHSEnv,
  writeShellScript,
  writeShellScriptBin,
  nodejs_22,
  symlinkJoin,
}:

let
  pname = "auto-rob";
  version = "0.2.2";

  # Upstream Electron Forge zip ≈ contents of /usr/lib/electron-svelte from the .deb
  auto-rob-unwrapped = stdenv.mkDerivation {
    pname = "${pname}-unwrapped";
    inherit version;

    src = fetchurl {
      url = "https://github.com/Cattn/auto-rob/releases/download/v${version}/electron-svelte-linux-x64-${version}.zip";
      hash = "sha256-8a3N8NUIL7gXKNiLGyyQtKF3BfJsegp3mk+DidQuiWc=";
    };

    nativeBuildInputs = [ unzip ];

    # Deb layout: /usr/lib/electron-svelte/* + /usr/bin/electron-svelte → that dir
    installPhase = ''
      runHook preInstall

      mkdir -p $out/lib/electron-svelte
      if [ -f ./electron-svelte ]; then
        cp -a . $out/lib/electron-svelte/
      elif [ -d ./electron-svelte-linux-x64 ]; then
        cp -a ./electron-svelte-linux-x64/. $out/lib/electron-svelte/
      else
        echo "unexpected zip layout:" >&2
        find . -maxdepth 2 >&2
        exit 1
      fi

      chmod +x $out/lib/electron-svelte/electron-svelte
      # The release includes a bundled CLI. Use Nix's Node rather than the
      # upstream ELF, so headless commands also work outside the FHS env.
      test -f $out/lib/electron-svelte/cli/cli.mjs
      substituteInPlace $out/lib/electron-svelte/auto-rob \
        --replace-fail '"$directory/cli/node"' '${nodejs_22}/bin/node'
      rm $out/lib/electron-svelte/cli/node
      # chrome-sandbox is useless without setuid in the nix store
      rm -f $out/lib/electron-svelte/chrome-sandbox

      mkdir -p $out/bin
      ln -s ../lib/electron-svelte/electron-svelte $out/bin/electron-svelte
      ln -s ../lib/electron-svelte/auto-rob $out/bin/auto-rob

      install -Dm644 ${./icon.png} $out/share/pixmaps/auto-rob.png
      install -Dm644 ${./icon.png} $out/share/icons/hicolor/256x256/apps/auto-rob.png

      runHook postInstall
    '';

    meta = {
      platforms = [ "x86_64-linux" ];
    };
  };

  auto-rob-run = writeShellScript "auto-rob" ''
    cd ${auto-rob-unwrapped}/lib/electron-svelte
    exec ./electron-svelte \
      --no-sandbox \
      ''${NIXOS_OZONE_WL:+''${WAYLAND_DISPLAY:+--ozone-platform-hint=auto --enable-features=WaylandWindowDecorations --enable-wayland-ime=true}} \
      "$@"
  '';
  gui = buildFHSEnv {
    name = "auto-rob-gui";

    targetPkgs =
      pkgs: with pkgs; [
        systemd
        dbus
        cups
        cairo
        pango
        gdk-pixbuf
        atk
        gtk3
        glib
        nss
        nspr
        at-spi2-atk
        at-spi2-core
        libdrm
        libxkbcommon
        mesa
        libgbm
        libx11
        libxcomposite
        libxdamage
        libxext
        libxfixes
        libxrandr
        libxcb
        libxcursor
        libxi
        alsa-lib
        libpulseaudio
        libGL
        libva
        vulkan-loader
        expat
        fontconfig
        freetype
        harfbuzz
        zlib
        libnotify
        xdg-utils
      ];

    runScript = auto-rob-run;

    # Upstream checks this path before installing a mutable CLI and editing
    # shell profiles. Home Manager already supplies our packaged launcher.
    extraBuildCommands = ''
      ln -s ${auto-rob-unwrapped}/lib/electron-svelte/auto-rob $out/usr/bin/auto-rob
    '';

    extraInstallCommands = ''
          mkdir -p $out/share/applications $out/share/pixmaps $out/share/icons/hicolor/256x256/apps
          cp -r ${auto-rob-unwrapped}/share/pixmaps/* $out/share/pixmaps/
          cp -r ${auto-rob-unwrapped}/share/icons/* $out/share/icons/

          cat > $out/share/applications/auto-rob.desktop << 'DESKTOP'
      [Desktop Entry]
      Type=Application
      Name=auto-rob
      GenericName=Portfolio Agent
      Comment=Autonomous Robinhood portfolio agent
      Exec=auto-rob --gui %U
      Icon=auto-rob
      Terminal=false
      Categories=Finance;Office;
      StartupNotify=true
      StartupWMClass=electron-svelte
      DESKTOP
    '';
  };

  cli = writeShellScriptBin "auto-rob" ''
    if [ "''${1-}" = "--gui" ]; then
      shift
      exec ${gui}/bin/auto-rob-gui "$@"
    fi
    exec ${nodejs_22}/bin/node ${auto-rob-unwrapped}/lib/electron-svelte/cli/cli.mjs "$@"
  '';
in
symlinkJoin {
  name = "${pname}-${version}";
  inherit version;
  paths = [
    cli
    gui
  ];

  passthru.unwrapped = auto-rob-unwrapped;

  meta = with lib; {
    description = "Autonomous Robinhood portfolio agent";
    homepage = "https://github.com/Cattn/auto-rob";
    downloadPage = "https://github.com/Cattn/auto-rob/releases/tag/v${version}";
    license = licenses.isc;
    platforms = [ "x86_64-linux" ];
    mainProgram = "auto-rob";
    sourceProvenance = with sourceTypes; [ binaryNativeCode ];
  };
}
