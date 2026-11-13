{ config, lib, pkgs, ... }:

{
  # Upstream's t3code-wow installer puts its writable launcher here.
  home.sessionPath = [ "${config.home.homeDirectory}/.local/bin" ];

  # Refresh inherited sessions too: hm-session-vars.sh runs only once per login.
  programs.zsh.envExtra = ''
    typeset -U path
    path=("${config.home.homeDirectory}/.local/bin" $path)
  '';

  # Keep upstream's service writable so its installer/updater can replace it.
  # Pin the runtime through HM instead of retaining an obsolete Node store path
  # and the terminal's PATH from the day the bridge was installed.
  xdg.configFile."systemd/user/t3code-wow.service.d/nix.conf".text = ''
    [Service]
    ExecStart=
    ExecStart=${pkgs.nodejs}/bin/node "${config.xdg.dataHome}/t3code-wow/bridge/bin/t3code-wow.js" run
    Environment="PATH=${lib.makeBinPath [ pkgs.nodejs pkgs.grim pkgs.imagemagickBig ]}:%h/.local/bin:%h/.nix-profile/bin:/etc/profiles/per-user/%u/bin:/run/current-system/sw/bin"
  '';

  home.packages = with pkgs; [
    nodejs # t3code-wow needs Node >= 22.
    grim # Pixel-strip capture on niri/Hyprland; also available to install.sh.
    (heroic.override {
      extraPkgs = pkgs': with pkgs'; [ gamemode ];
    })
    prismlauncher
    wineWow64Packages.stagingFull
    winetricks
    protonup-qt
    wowup-cf
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
