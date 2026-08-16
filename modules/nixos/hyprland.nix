{
  # NixOS Hyprland session registration. Session glue (polkit, pam_kwallet_init, …)
  # lives in modules/home/hyprland — do not import this for niri/Plasma-only hosts.
  programs.hyprland.enable = true;
}
