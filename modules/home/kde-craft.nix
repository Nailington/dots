{ pkgs, config, ... }:

{
  # Wrappers only — CraftRoot is mutable and must not be managed by Home Manager.
  home.packages = [ pkgs.kde-craft ];

  home.sessionVariables.CRAFT_ROOT = "${config.home.homeDirectory}/CraftRoot";
}
