{ pkgs, lib, ... }:

{
  imports = [
    ./zsh.nix
    ./ssh.nix
  ];

  home.sessionVariables = {
    EDITOR = "nano";
  };

  programs.home-manager.enable = true;

  home.packages = with pkgs; [
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
