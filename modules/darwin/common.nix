{ pkgs, inputs, config, ... }:

let
  inherit
    (import ../../pkgs/nh-wrapped.nix {
      inherit pkgs;
      syncAgeRecipientsText = builtins.readFile ../../scripts/sync-age-recipients.sh;
    })
    nh
    sync-age-recipients
    ;
in
{
  imports = [
    inputs.nix-homebrew.darwinModules.nix-homebrew
    ./ssh.nix
  ];

  programs.zsh.enable = true;

  environment.systemPackages = [
    pkgs.vim
    pkgs.git
    pkgs.wget
    pkgs.curl
    pkgs.age
    nh
    sync-age-recipients
  ];

  nix-homebrew = {
    enable = true;
    # Intel Mac — Rosetta prefix is Apple Silicon only.
    enableRosetta = false;
    user = "potter";
    taps = {
      "homebrew/homebrew-core" = inputs.homebrew-core;
      "homebrew/homebrew-cask" = inputs.homebrew-cask;
    };
    mutableTaps = false;
    autoMigrate = true;
  };

  homebrew = {
    enable = true;
    taps = builtins.attrNames config.nix-homebrew.taps;
    onActivation = {
      cleanup = "uninstall";
      autoUpdate = false;
      upgrade = false;
    };
    brews = [ ];
    casks = [ "bluebubbles" ];
  };
}
