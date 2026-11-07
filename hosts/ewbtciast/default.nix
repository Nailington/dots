{ pkgs, ... }:

{
  imports = [ ../../modules/darwin/common.nix ];

  networking.hostName = "ewbtciast";

  # 2017 Intel iMac (OCLP). Keep eval/build load down.
  # nix.settings is ignored while Determinate owns nix.conf; this goes to nix.custom.conf.
  determinateNix.customSettings = {
    max-jobs = 2;
    lazy-trees = true;
    eval-cores = 1;
    # Download any matching Darwin outputs copied to abacab; no remote builds.
    extra-substituters = [ "http://100.120.61.10:5000" ];
    extra-trusted-public-keys = [
      (pkgs.lib.trim (builtins.readFile ../../secrets/abacab-cache.pub))
    ];
  };

  system.primaryUser = "potter";
  system.stateVersion = 6;

  users.users.potter = {
    name = "potter";
    home = "/Users/potter";
    shell = pkgs.zsh;
  };
}
