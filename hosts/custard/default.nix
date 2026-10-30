{ ... }:

{
  imports = [
    ./hardware-configuration.nix
    ./disk.nix
    ../../modules/nixos/common.nix
    ../../modules/nixos/desktop.nix
    ../../modules/nixos/niri.nix
    ../../modules/nixos/tailscale.nix
    # ../../modules/nixos/hyprland.nix # Hyprland + SDDM — use instead of niri.
    # ../../modules/nixos/plasma.nix # Plasma + SDDM — use instead of niri.
    # ../../modules/nixos/gaming.nix # Steam and its x86 runtime do not support this Pi.
    # ../../modules/nixos/virtualisation.nix # Includes x86-only VMware; Docker is enabled below.
  ];

  networking.hostName = "custard";
  networking.networkmanager.wifi.powersave = false;
  hardware.enableRedistributableFirmware = true;
  hardware.graphics.enable = true;
  boot.supportedFilesystems = [ "ntfs" ];

  users.users.potter = {
    isNormalUser = true;
    description = "Potter";
    extraGroups = [ "wheel" "networkmanager" "docker" ];
    # Set a local password with passwd after SSH enrollment; no default password.
  };

  virtualisation.docker = {
    enable = true;
    enableOnBoot = false;
  };

  # This Pi has 4 GB of RAM. Avoid exhausting it during native builds.
  zramSwap.enable = true;
  nix.settings = {
    max-jobs = 1;
    cores = 2;
  };

  # A new installation; existing hosts retain their original stateVersion.
  system.stateVersion = "26.05";
}
