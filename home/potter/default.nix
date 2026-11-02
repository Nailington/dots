# Shared potter Home Manager identity — import on every potter home (NixOS, HM-only, Darwin later).
{ config, lib, ... }:

{
  options.potter.flakeDirectory = lib.mkOption {
    type = lib.types.strMatching "/.*";
    default = "${config.home.homeDirectory}/dots";
    description = "Writable local flake checkout used by desktop configuration symlinks.";
  };

  config = {
    home.username = "potter";
    home.homeDirectory = "/home/potter";
    home.stateVersion = "25.11";
  };
}
