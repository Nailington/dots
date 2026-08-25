{ inputs, ... }:

{
  # niri + DankMaterialShell. Do not import modules/home/hyprland.
  # KWallet PAM unlock: modules/home/kwallet.nix (graphical-session-pre).
  # niri-flake HM config is injected by modules/nixos/niri.nix (sharedModules).
  imports = [
    inputs.dms.homeModules.dank-material-shell
    inputs.dms.homeModules.niri
  ];

  # Empty settings → niri-flake’s stock config (written to ~/.config/niri/hm.kdl).
  # DMS niri.includes rewrites config.kdl to include hm.kdl + dms/*.kdl.
  programs.niri.settings = { };

  programs.dank-material-shell = {
    enable = true;
    # systemd autostart (not niri.enableSpawn — do not enable both).
    systemd = {
      enable = true;             # Systemd service for auto-start
      restartIfChanged = true;   # Auto-restart dms.service when dank-material-shell changes
    };

    enableSystemMonitoring = true;     # System monitoring widgets (dggiop)
    enableVPN = true;                  # VPN management widget
    enableDynamicTheming = true;       # Wallpaper-based theming (matugen)
    enableAudioWavelength = true;      # Audio visualizer (cava)
    # enableCalendarEvents = true;       # Calendar integration (khal)

    # Do not set niri.enableKeybinds; it conflicts with includes.
    niri.includes = {
      enable = true;
      override = true;
      originalFileName = "hm";
      filesToInclude = [
        "alttab"
        "binds"
        "colors"
        "cursor"
        "layout"
        "outputs"
        "windowrules"
        "wpblur"
      ];
    };
  };
}
