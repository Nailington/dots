{ stdenv
, rofi
, makeWrapper
, lib
, rofiThemesSrc
}:

stdenv.mkDerivation rec {
  pname = "rofi-themes-collection";
  version = "unstable";

  src = rofiThemesSrc;

  nativeBuildInputs = [ makeWrapper ];

  dontBuild = true;

  installPhase = ''
    runHook preInstall

    # Create directory structure
    mkdir -p $out/share/rofi
    mkdir -p $out/bin

    # Copy all rofi config files from the 'files' directory
    if [ -d "files" ]; then
      cp -r files/* $out/share/rofi/
    else
      # If no files directory, copy everything except metadata
      cp -r . $out/share/rofi/
      rm -rf $out/share/rofi/.git $out/share/rofi/.github
    fi

    # Make all scripts executable
    find $out/share/rofi -name "*.sh" -exec chmod +x {} \;

    # Create wrapper scripts for launchers (type 1-7)
    for i in 1 2 3 4 5 6 7; do
      if [ -f "$out/share/rofi/launchers/type-$i/launcher.sh" ]; then
        makeWrapper $out/share/rofi/launchers/type-$i/launcher.sh $out/bin/launcher_t$i \
          --prefix PATH : ${rofi}/bin \
          --run "cd $out/share/rofi/launchers/type-$i"
      fi
    done

    # Create wrapper scripts for powermenus (type 1-6)
    for i in 1 2 3 4 5 6; do
      if [ -f "$out/share/rofi/powermenu/type-$i/powermenu.sh" ]; then
        makeWrapper $out/share/rofi/powermenu/type-$i/powermenu.sh $out/bin/powermenu_t$i \
          --prefix PATH : ${rofi}/bin \
          --run "cd $out/share/rofi/powermenu/type-$i"
      fi
    done

    runHook postInstall
  '';

  meta = with lib; {
    description = "A huge collection of Rofi based custom Applets, Launchers & Powermenus (Nailington fork)";
    homepage = "https://github.com/Nailington/rofi";
    license = licenses.gpl3;
    platforms = platforms.linux;
  };
}
