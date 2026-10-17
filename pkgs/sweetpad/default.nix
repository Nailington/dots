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
    rev = "4ca8adc734854c49acd9b61440522853659c4719";
    hash = "sha256-WKY7eZpcBY66d8oQJBczb9Og4ZgRG3rVloXdabp95ho=";
  };

  vscodeExtension = buildNpmPackage {
    pname = "sweetpad-vscode";
    version = "0.2.18";
    inherit src;

    npmDepsHash = "sha256-TwN7PEmPA5j2h+WnZ22mfZQGi5kco0wH/h79QR5xkac=";
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
  version = "0-unstable-2026-10-16";
  inherit src;

  cargoHash = "sha256-LyhqV4L3KJQjwgQSj0KJje+aMZjzENqaL5Pjocoixx4=";
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
