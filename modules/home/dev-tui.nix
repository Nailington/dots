{ pkgs, ... }:

{
  programs.java = {
    enable = true;
    package = pkgs.jdk21;
  };

  home.packages = with pkgs; [
    cursor-cli
    gh
    nodejs
    bun
    pnpm
    nil
    nixd
    quickemu
    ffmpeg-full
    imagemagickBig
  ];
}
