{ pkgs, ... }:

{
  # ARM GUI development tools, without the local x86-only SweetPad/sim-relay.
  home.packages = with pkgs; [
    github-desktop
    meld
  ];
}
