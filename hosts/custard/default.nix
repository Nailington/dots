{ pkgs, ... }:

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

  # Place this private keyfile on the flashed card, outside the Nix build/store.
  # Import before NetworkManager starts so Wi-Fi connects without a login.
  systemd.services.custard-wifi-bootstrap = {
    description = "Import custard's first-boot Wi-Fi connection";
    wantedBy = [ "NetworkManager.service" ];
    before = [ "NetworkManager.service" ];
    unitConfig = {
      RequiresMountsFor = "/boot/firmware";
      ConditionPathExists = "/boot/firmware/custard-wifi.nmconnection";
    };
    serviceConfig.Type = "oneshot";
    path = [ pkgs.coreutils ];
    script = ''
      profiles=/etc/NetworkManager/system-connections
      install -d -m 0700 "$profiles"
      install -m 0600 -o root -g root /boot/firmware/custard-wifi.nmconnection \
        "$profiles/custard-wifi.nmconnection.tmp"
      mv -f "$profiles/custard-wifi.nmconnection.tmp" "$profiles/custard-wifi.nmconnection"
      sync -f "$profiles/custard-wifi.nmconnection"
      rm /boot/firmware/custard-wifi.nmconnection
    '';
  };

  hardware.enableRedistributableFirmware = true;
  hardware.graphics.enable = true;
  boot.supportedFilesystems = [ "ntfs" ];

  users.users.potter = {
    isNormalUser = true;
    description = "Potter";
    extraGroups = [ "wheel" "networkmanager" "docker" ];
    # Initial desktop/sudo password; change it later with passwd.
    initialHashedPassword = "$y$j9T$77GgtrrOntgRVBQrFk1j/0$onpad/mNxL7QV7p244qubRmZWf1y81SsDK2rQqcpIr8";
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
