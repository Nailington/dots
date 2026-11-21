{ lib
, rustPlatform
, fetchFromGitHub
, runCommand
, coreutils
}:

# qpernil's virtual YubiKey for Raspberry Pi USB gadget mode. Upstream is five
# sibling repositories joined by relative path dependencies, so they are pinned
# together and laid out side by side. The result is the unprivileged worker and
# touch helper; `.supervisor` is the root-side USB gadget supervisor.
#
# Upstream describes this as "a software test double, not a security device":
# keys live unencrypted under /var/lib/virtual-yubikey.

let
  github = repo: rev: hash: fetchFromGitHub {
    owner = "qpernil";
    inherit repo rev hash;
  };

  sources = {
    virtual-yubikey = github "virtual-yubikey"
      "a47e0ba877b82dd7b05f2ca5b888e91b6af69913"
      "sha256-Sy1IWN0BfwQB/0c9bl9WQSmqqdtCgPrALgnY0UFdaJk=";
    usb-gadget-supervisor = github "usb-gadget-supervisor"
      "9db9acea93064ad9498986230893869eb861230c"
      "sha256-bDIONEZdhyzNqbJZa143VDNjKJ4cexu50w8F4lKOo1w=";
    display-backends = github "display-backends"
      "0ab7f00b74033c8eb40e73bcb1fba1a3d4a3df4e"
      "sha256-y93WMU2Ydz8f9bf8c+ddfGHUcXdzWY9kTpq+mHdeDEM=";
    software-key-core = github "software-key-core"
      "8cfbfc1cd1f7fc63d22cb189062e634d692e5b43"
      "sha256-CsieJBiArnS2EXow1IgPBXBUjbLrDLRNmiOtyA8Qkc8=";
    raspberry-pi-i2c-target = github "raspberry-pi-i2c-target"
      "70d8100076da4a0f3b91c80b262c7a2ffb307dc3"
      "sha256-9IpQxiKacnWU8sAyFDyCcENFmC6j64lylTWQ2pkWY4w=";
  };

  workspace = runCommand "virtual-yubikey-workspace" { } ''
    mkdir $out
    ${lib.concatStringsSep "\n" (lib.mapAttrsToList
      (name: source: "cp -r --no-preserve=mode ${source} $out/${name}")
      sources)}
  '';

  version = "0.1.0-unstable-2026-11-15";

  meta = {
    homepage = "https://github.com/qpernil/virtual-yubikey";
    license = with lib.licenses; [ mit asl20 ];
    platforms = [ "aarch64-linux" ];
  };

  supervisor = rustPlatform.buildRustPackage {
    pname = "usb-gadget-supervisor";
    inherit version;
    src = workspace;
    sourceRoot = "${workspace.name}/usb-gadget-supervisor";
    cargoLock.lockFile = ./usb-gadget-supervisor.Cargo.lock;

    # NixOS has no /usr/bin/id; the supervisor uses it to resolve run_as.
    postPatch = ''
      substituteInPlace src/runtime.rs \
        --replace-fail '"/usr/bin/id"' '"${coreutils}/bin/id"'
    '';

    doCheck = false;
    meta = meta // {
      description = "Privilege-separated Linux USB gadget supervisor";
      homepage = "https://github.com/qpernil/usb-gadget-supervisor";
      mainProgram = "usb-gadget-supervisor";
    };
  };
in
rustPlatform.buildRustPackage {
  pname = "virtual-yubikey";
  inherit version;
  src = workspace;
  sourceRoot = "${workspace.name}/virtual-yubikey";
  cargoLock.lockFile = ./virtual-yubikey.Cargo.lock;

  cargoBuildFlags = [
    "--bin"
    "virtual-yubikey-worker"
    "--bin"
    "virtual-yubikey-touch"
  ];

  doCheck = false;

  passthru = { inherit supervisor; };

  meta = meta // {
    description = "Virtual YubiKey (FIDO2/U2F, PIV, OpenPGP, OATH) for Raspberry Pi USB gadget mode";
    mainProgram = "virtual-yubikey-worker";
  };
}
