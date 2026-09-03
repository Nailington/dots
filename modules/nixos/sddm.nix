{
  # SDDM for Hyprland and Plasma. niri uses greetd + dms-greeter
  # (modules/nixos/niri.nix) and must not import this module.
  services.displayManager.sddm.enable = true;
  services.displayManager.sddm.settings.General.Numlock = "on";
}
