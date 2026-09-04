{ pkgs, inputs, config, ... }:

{
  imports = [ inputs.nix-homebrew.darwinModules.nix-homebrew ];

  nix.settings.experimental-features = [
    "nix-command"
    "flakes"
  ];

  programs.zsh.enable = true;

  environment.systemPackages = with pkgs; [
    vim
    git
    wget
    curl
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
    casks = [ ];
  };
}
