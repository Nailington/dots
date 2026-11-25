{ inputs, pkgs, lib, ... }:

{
  imports = [
    ./zsh.nix
    ./ssh.nix
  ];

  home.sessionVariables = {
    CLAUDE_CODE_EXPERIMENTAL_CODE_MODE = "1";
    EDITOR = "nano";
  };

  programs.home-manager.enable = true;

  home.packages = with pkgs; [
    (if lib.versionOlder claude-code.version "2.1.323" then
      callPackage (inputs.nixpkgs + "/pkgs/by-name/cl/claude-code/package.nix") { }
    else
      claude-code)
    lynx
    w3m
    nix-du
    ncdu
    unrar
    fastfetch
    (btop.override {
      rocmSupport = pkgs.stdenv.hostPlatform.isx86_64;
      cudaSupport = pkgs.stdenv.hostPlatform.isx86_64;
    })
    lshw
    libinput
    nmap
    screen
    nix-index
    zip
    unzip
    sqlite
    tea
  ] ++ lib.optionals pkgs.stdenv.hostPlatform.isx86_64 [
    pkgs.auto-rob # The local Electron release is x86_64-only.
  ];
}
