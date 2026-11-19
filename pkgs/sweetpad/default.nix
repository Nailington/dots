{ lib
, stdenv
, fetchurl
, autoPatchelfHook
, makeWrapper
, installShellFiles
, openssh
}:

stdenv.mkDerivation (finalAttrs: {
  pname = "sweetpad";
  version = "0.1.12-nailington.3";

  src = fetchurl {
    url = "https://github.com/Nailington/sweetpad/releases/download/cli-v${finalAttrs.version}/sweetpad-cli-${finalAttrs.version}-linux-x64.tar.gz";
    hash = "sha256-1mJg2rxFsnnomcNJnHsQDmv49FKqBgLzDQ7zHX4NYnM=";
  };

  sourceRoot = ".";
  nativeBuildInputs = [ autoPatchelfHook makeWrapper installShellFiles ];
  buildInputs = [ stdenv.cc.cc.lib ];
  dontBuild = true;

  installPhase = ''
    runHook preInstall
    install -Dm755 sweetpad "$out/bin/sweetpad"
    wrapProgram "$out/bin/sweetpad" --prefix PATH : ${lib.makeBinPath [ openssh ]}
    runHook postInstall
  '';

  postInstall = ''
    sweetpadCompletions() {
      "$out/bin/sweetpad" completions zsh > _sweetpad
      installShellCompletion --zsh _sweetpad
    }
    postFixupHooks+=(sweetpadCompletions)
  '';

  meta = {
    description = "SweetPad CLI with remote Xcode builds from Linux";
    homepage = "https://github.com/Nailington/sweetpad";
    license = with lib.licenses; [ mit asl20 ];
    mainProgram = "sweetpad";
    platforms = [ "x86_64-linux" ];
  };
})
