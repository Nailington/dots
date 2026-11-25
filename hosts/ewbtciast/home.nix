{ inputs, lib, pkgs, ... }:

let
  claudeCode =
    if lib.versionOlder pkgs.claude-code.version "2.1.323" then
      (pkgs.callPackage (inputs.nixpkgs + "/pkgs/by-name/cl/claude-code/package.nix") { }).overrideAttrs (old: {
        meta = old.meta // { platforms = old.meta.platforms ++ [ "x86_64-darwin" ]; };
      })
    else
      pkgs.claude-code;
in

{
  imports = [
    ../../modules/home/zsh.nix
    ../../modules/home/ssh.nix
  ];

  home.username = "potter";
  home.homeDirectory = "/Users/potter";
  home.stateVersion = "25.11";

  home.sessionVariables = {
    CLAUDE_CODE_EXPERIMENTAL_CODE_MODE = "1";
    EDITOR = "nano";
  };
  programs.home-manager.enable = true;

  home.packages = [ claudeCode pkgs.lynx pkgs.w3m ];
}
