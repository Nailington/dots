{ lib
, fetchFromGitHub
, rustPlatform
, buildNpmPackage
, pkg-config
, openssl
, makeWrapper
, installShellFiles
, openssh
, vsce
, python3
}:

let
  # Remote Mac support is on this fork branch, not main or the Marketplace.
  src = fetchFromGitHub {
    owner = "Nailington";
    repo = "sweetpad";
    rev = "faa56b037eaf574a5cfd4bf9f213da5033c9f82f";
    hash = "sha256-DY2HwBw3nBeKl+B1FPcEB6yR4pJ43Qdf3Cw/aKyKlBI=";
  };

  vscodeExtension = buildNpmPackage {
    pname = "sweetpad-vscode";
    version = "0.2.18";
    inherit src;

    npmDepsHash = "sha256-dnZeH5n/nIsCd5p4EkSjCU6AUSkg3emI79gYREwCSpQ=";
    npmDepsFetcherVersion = 2;
    # Select by package name; the directory selector includes the native workspace.
    npmWorkspace = "sweetpad";
    # The Linux remote extension needs no Mac native addon or node-pty build.
    npmFlags = [ "--ignore-scripts" ];
    nativeBuildInputs = [ vsce ];

    installPhase = ''
      runHook preInstall
      cd sweetpad-vscode
      mkdir -p "$out/share/vscode/extensions/sweetpad.sweetpad" "$out/share/vsix"
      vsce package --no-dependencies --out "$out/share/vsix/sweetpad.vsix"
      cp -r package.json out images README.md CHANGELOG.md LICENSE.md \
        "$out/share/vscode/extensions/sweetpad.sweetpad/"
      runHook postInstall
    '';

    passthru = {
      vscodeExtPublisher = "sweetpad";
      vscodeExtName = "sweetpad";
      vscodeExtUniqueId = "sweetpad.sweetpad";
    };

    meta = {
      description = "SweetPad editor extension with remote Mac support";
      homepage = "https://github.com/Nailington/sweetpad/tree/codex/windows-remote-testing";
      license = lib.licenses.mit;
      platforms = lib.platforms.linux;
    };
  };
in
rustPlatform.buildRustPackage {
  pname = "sweetpad";
  version = "0.2.18-nailington-unstable-2026-11-14";
  inherit src;

  cargoHash = "sha256-qKv6+nKRhJYkb9hbomW37nw9FAedhaEkcL9zfKmd9Tw=";
  cargoBuildFlags = [ "-p" "sweetpad-cli" ];
  cargoTestFlags = [ "-p" "sweetpad-cli" ];
  # Nix supplies a log terminal without an interactive /dev/tty for prompts.
  env.CI = "true";
  nativeBuildInputs = [ pkg-config makeWrapper installShellFiles ];
  nativeCheckInputs = [ python3 ];
  buildInputs = [ openssl ];

  postPatch = ''
    # The DAP tests generate this executable from a Rust string at runtime.
    substituteInPlace sweetpad-cli/tests/dap_proxy.rs \
      --replace-fail '#!/usr/bin/env python3' '#!${python3}/bin/python3'
  '';

  postInstall = ''
    "$out/bin/sweetpad" completions zsh > _sweetpad
    installShellCompletion --zsh _sweetpad
    wrapProgram "$out/bin/sweetpad" --prefix PATH : ${lib.makeBinPath [ openssh ]}
  '';

  passthru = { inherit vscodeExtension; };

  meta = {
    description = "SweetPad CLI with remote Xcode builds from Linux";
    homepage = "https://github.com/Nailington/sweetpad/tree/codex/windows-remote-testing";
    license = with lib.licenses; [ mit asl20 ];
    mainProgram = "sweetpad";
    platforms = lib.platforms.linux;
  };
}
