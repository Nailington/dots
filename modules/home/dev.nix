{ pkgs, ... }:

{
  programs.java = {
    enable = true;
    package = pkgs.jdk21;
  };

  home.packages = with pkgs; [
    code-cursor
    cursor-cli
    github-desktop
    gh
    nodejs
    bun
    pnpm_9
    nil
    nixd
    quickemu
    quickgui
    virt-manager
  ];
}
