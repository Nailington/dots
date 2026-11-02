{ config, ... }:

{
  imports = [
    ../../modules/home/common.nix
    ../../modules/home/arm/desktop.nix
    ../../modules/home/niri
    ../../modules/home/kitty
    ../../modules/home/kde-apps.nix
    ../../modules/home/arm/gaming.nix
    ../../modules/home/arm/creative.nix
    ../../modules/home/dev-tui.nix
    ../../modules/home/arm/dev-gui.nix
    # ../../modules/home/desktop.nix # Mixed x86-only apps; use arm/desktop.nix.
    # ../../modules/home/dev-gui.nix # Includes x86-only local SweetPad/sim-relay packages.
    # ../../modules/home/gaming.nix # Includes x86-only games/Wine; use arm/gaming.nix.
    # ../../modules/home/creative.nix # Includes CUDA OBS/Unity; use arm/creative.nix.
    # ../../modules/home/spicetify.nix # Spotify's Linux client is x86-only.
    # ../../modules/home/osx-kvm # Intel macOS guests need an x86 host.
  ];

  # Pi display modes stay writable without changing the laptop's monitor setup.
  xdg.configFile."niri/dms/outputs.kdl".source = config.lib.file.mkOutOfStoreSymlink (
    "${config.potter.flakeDirectory}/hosts/custard/outputs.kdl"
  );

  # Bind the background T3 server to custard's Tailscale address.
  xdg.configFile."systemd/user/t3code.service.d/host.conf".text = ''
    [Service]
    Environment="T3CODE_HOME=%h/.t3"
    Environment="T3CODE_HOST=100.71.39.67"
    Environment="T3CODE_PORT=3773"
  '';
}
