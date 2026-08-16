{
  # Full KDE Plasma desktop (includes Dolphin/Ark/KWallet UI/etc. — no home/kde-apps.nix needed).
  # Pair with modules/nixos/desktop.nix; do not import modules/nixos/hyprland.nix unless you want both sessions.
  services.desktopManager.plasma6.enable = true;
}
