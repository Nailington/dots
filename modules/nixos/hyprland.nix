{
  # NixOS Hyprland session + SDDM. Session glue (polkit, …) lives in
  # modules/home/hyprland. Do not import modules/nixos/niri.nix (dms-greeter).
  imports = [ ./sddm.nix ];

  programs.hyprland.enable = true;
}
