{ lib
, python3
, fetchFromGitHub
}:

let
  pythonEnv = python3.withPackages (ps: with ps; [
    blessed
  ]);
in

python3.pkgs.buildPythonApplication {
  pname = "singularcard";
  version = "unstable-2025-03-17";
  format = "other";

  src = fetchFromGitHub {
    owner = "HammerPot";
    repo = "SingularCard";
    rev = "7b5e8feb748ae7de6c8c3cfdce58f9fb8f1e8f5d";
    hash = "sha256-DcmcXmEA0JzHCJinLRLF9HXj3D2IjOL9kpwt8QFuRqI=";
  };

  propagatedBuildInputs = with python3.pkgs; [
    blessed
  ];

  dontBuild = true;
  dontConfigure = true;

  installPhase = ''
    runHook preInstall

    mkdir -p $out/lib/singularcard $out/bin
    cp main.py deck.json cardFont.json $out/lib/singularcard/

    cat > $out/bin/singularcard << EOF
#!/bin/sh
cd $out/lib/singularcard
exec ${pythonEnv}/bin/python3 $out/lib/singularcard/main.py "\$@"
EOF
    chmod +x $out/bin/singularcard

    runHook postInstall
  '';

  meta = with lib; {
    description = "Terminal-based Uno card game (SingularCard)";
    homepage = "https://github.com/HammerPot/SingularCard";
    license = licenses.unfree;
    platforms = platforms.all;
    mainProgram = "singularcard";
  };
}
