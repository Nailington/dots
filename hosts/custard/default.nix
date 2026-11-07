{ lib, pkgs, ... }:

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

  # Advertise this Pi as an exit node whenever Tailscale starts.
  services.tailscale.extraSetFlags = [ "--advertise-exit-node" ];

  # Codex Desktop's bundled Node dependency audit segfaults under QEMU ARM.
  # Re-enable after the packaging/emulation issue is resolved or built natively.
  programs.codexDesktopLinux.enable = lib.mkForce false;

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

  # Only this client offloads uncached ARM builds to abacab.
  nix.distributedBuilds = true;
  nix.buildMachines = [
    {
      hostName = "100.120.61.10";
      protocol = "ssh-ng";
      sshUser = "nix-builder";
      sshKey = "/home/potter/.ssh/id_ed25519";
      system = "aarch64-linux";
      maxJobs = 2;
      supportedFeatures = [ "big-parallel" ];
    }
  ];
  programs.ssh.knownHosts.abacab-builder = {
    hostNames = [ "100.120.61.10" "abacab" ];
    publicKey = lib.trim (builtins.readFile ../../secrets/ssh/abacab/ssh_host_ed25519_key.pub);
  };

  # This Pi has 4 GB of RAM. Leave compilation to the remote builder.
  zramSwap.enable = true;
  swapDevices = [
    {
      device = "/swapfile";
      size = 64 * 1024;
    }
  ];
  nix.settings = {
    max-jobs = 0;
    cores = 2;
    builders-use-substitutes = true;
  };

  # A new installation; existing hosts retain their original stateVersion.
  system.stateVersion = "26.05";
}
