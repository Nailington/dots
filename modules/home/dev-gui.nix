{ pkgs, ... }:

{
  home.packages = with pkgs; [
    code-cursor
    github-desktop
    quickgui
  ];
}
