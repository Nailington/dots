{ pkgs, inputs, ... }:

{
  # niri + DankMaterialShell. Do not import modules/home/hyprland.
  imports = [
    inputs.dms.homeModules.dank-material-shell
  ];

  # Don't let niri-flake generate config.kdl; we ship it from this directory.
  programs.niri.config = null;

  xdg.configFile."niri/config.kdl".source = ./config.kdl;
  xdg.configFile."niri/dms" = {
    source = ./dms;
    recursive = true;
  };
  # libexec is not on PATH; niri spawn-at-startup is the Hyprland exec-once equivalent.
  xdg.configFile."niri/pam-kwallet.kdl".text = ''
    spawn-at-startup "${pkgs.kdePackages.kwallet-pam}/libexec/pam_kwallet_init"
  '';

  programs.dank-material-shell = {
    enable = true;
    systemd = {
      enable = true;
      restartIfChanged = true;
    };

    enableSystemMonitoring = true;
    enableVPN = true;
    enableDynamicTheming = true;
    enableAudioWavelength = true;
  };
}
