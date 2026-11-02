{ ... }:

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

  # No fixed Tailscale bind address has been assigned to this new host.
  # Keep T3's default loopback binding until enrollment; the shared guard is for
  # roundabout/abacab, whose host.conf supplies their explicit T3CODE_HOST.
  xdg.configFile."systemd/user/t3code.service.d/tailscale.conf".enable = false;
  xdg.configFile."systemd/user/t3code.service.d/host.conf".text = ''
    [Service]
    Environment="T3CODE_HOME=%h/.t3"
    Environment="T3CODE_HOST=127.0.0.1"
    Environment="T3CODE_PORT=3773"
  '';
}
