{ pkgs, ... }:

{
  # Native ARM gaming apps, without the x86 games/Wine selection in ../gaming.nix.
  home.packages = with pkgs; [
    prismlauncher
  ];
}
