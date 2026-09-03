{
  # Full KDE Plasma desktop (includes Dolphin/Ark/KWallet UI/etc. — no home/kde-apps.nix needed).
  # Pair with modules/nixos/desktop.nix and SDDM. Do not import modules/nixos/niri.nix
  # (dms-greeter). Hyprland + Plasma together is fine (both use SDDM).
  imports = [ ./sddm.nix ];

  services.desktopManager.plasma6.enable = true;
}
