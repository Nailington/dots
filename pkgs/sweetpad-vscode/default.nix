{ lib, fetchurl, jq, vscode-utils }:

vscode-utils.buildVscodeExtension (finalAttrs: {
  pname = "sweetpad-vscode";
  version = "0.2.18-nailington";

  src = fetchurl {
    url = "https://github.com/Nailington/sweetpad/releases/download/v${finalAttrs.version}/sweetpad-${finalAttrs.version}.vsix";
    hash = "sha256-CTW1ATwxkRpUA/1hSVFxZH/LIZvSPe0LR07+0v3vhf4=";
  };

  vscodeExtPublisher = "sweetpad";
  vscodeExtName = "sweetpad";
  vscodeExtUniqueId = "sweetpad.sweetpad";
  nativeBuildInputs = [ jq ];

  postPatch = ''
    jq --arg publisher ${finalAttrs.vscodeExtPublisher} --arg name ${finalAttrs.vscodeExtName} \
      '.publisher = $publisher | .name = $name' package.json > package.json.tmp
    mv package.json.tmp package.json
  '';

  postInstall = ''
    install -Dm644 "$src" "$out/share/vsix/sweetpad.vsix"
  '';

  meta = {
    description = "SweetPad editor extension with remote Mac support";
    homepage = "https://github.com/Nailington/sweetpad";
    license = lib.licenses.mit;
    platforms = lib.platforms.linux;
  };
})
