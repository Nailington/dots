{ pkgs, ... }:

{
  imports = [ ../../modules/darwin/common.nix ];

  networking.hostName = "ewbtciast";

  # 2017 Intel iMac (OCLP). Keep eval/build load down.
  nix.settings.max-jobs = 2;

  system.primaryUser = "potter";
  system.stateVersion = 6;

  users.users.potter = {
    name = "potter";
    home = "/Users/potter";
    shell = pkgs.zsh;
  };
}
