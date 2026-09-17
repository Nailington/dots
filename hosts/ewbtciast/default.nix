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
  };

  system.primaryUser = "potter";
  system.stateVersion = 6;

  users.users.potter = {
    name = "potter";
    home = "/Users/potter";
    shell = pkgs.zsh;
  };
}
