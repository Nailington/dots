{ pkgs, ... }:

{
  # ARM creative apps, without the CUDA OBS/Unity selection in ../creative.nix.
  home.packages = with pkgs; [
    inkscape
  ];
}
