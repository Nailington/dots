{ pkgs, ... }:

{
  home.packages = with pkgs; [
    (heroic.override {
      extraPkgs = pkgs': with pkgs'; [ gamemode ];
    })
    prismlauncher
    wineWow64Packages.stagingFull
    winetricks
    protonup-qt
    lutris
    gamescope
    mangohud
    goverlay
    r2modman
    twitch-drops-miner
    mcpelauncher-client
    mcpelauncher-ui-qt
    cemu-ti
    retroarch-full
    ryubing
    azahar
    dolphin-emu
    cemu
  ];
}
