{ pkgs, ... }:

{
  programs.steam = {
    enable = true;
    remotePlay.openFirewall = true;
    dedicatedServer.openFirewall = true;
    extraPackages = with pkgs; [ gamemode ];
    protontricks.enable = true;
  };

  programs.gamemode = {
    enable = true;
    enableRenice = true;
    settings.general.renice = 10;
    settings.general.inhibit_screensaver = 1;
    settings.cpu.park_cores = "no";
    settings.cpu.pin_cores = "no";
  };

  # Expose libgamemode.so on the system path for Proton/Wine
  environment.systemPackages = [ pkgs.gamemode.lib ];
}
