{ lib, pkgs, ... }:

{
  imports = [
    ./hardware-configuration.nix
    ./disk.nix

    ../../modules/nixos/common.nix
    ../../modules/nixos/tailscale.nix
    # no mullvad / desktop / gaming on this host
  ];

  networking.hostName = "abacab";

  # Headless: systemd-networkd + static IPv4 (override NetworkManager from common.nix)
  networking.networkmanager.enable = lib.mkForce false;
  networking.useNetworkd = true;
  networking.useDHCP = false;
  networking.nameservers = [
    "1.1.1.1"
    "1.0.0.1"
  ];
  systemd.network.enable = true;
  systemd.network.networks."10-uplink" = {
    matchConfig.Name = "en* eth*";
    address = [ "45.92.216.66/23" ];
    gateway = [ "45.92.216.1" ];
    networkConfig = {
      DHCP = "no";
      DNS = [
        "1.1.1.1"
        "1.0.0.1"
      ];
      IPv6AcceptRA = false;
    };
  };

  # Existing data disk — mount only, never format. Kept out of disko on purpose.
  fileSystems."/mnt/storage" = {
    device = "/dev/disk/by-uuid/39ed1bbb-0ebf-43fd-a02e-62187377b916";
    fsType = "auto";
    options = [
      "defaults"
      "nofail"
      "x-systemd.device-timeout=10s"
    ];
  };

  # This host kexec'd in BIOS (not EFI). systemd-boot cannot boot that.
  boot.loader.systemd-boot.enable = false;
  boot.loader.efi.canTouchEfiVariables = false;
  boot.loader.grub = {
    enable = true;
    device = "/dev/sda";
    efiSupport = true;
    efiInstallAsRemovable = true;
  };

  services.openssh = {
    enable = true;
    settings = {
      PasswordAuthentication = false;
      KbdInteractiveAuthentication = false;
      PermitRootLogin = "prohibit-password";
    };
  };

  users.users.potter = {
    isNormalUser = true;
    description = "Potter";
    extraGroups = [
      "wheel"
    ];
  };

  # SSH keys: GitHub .keys + optional lib/ssh-keys.nix (modules/nixos/ssh-github.nix)

  # No initial password — key-only. Use `passwd` once if you ever need a local console password.
  security.sudo.wheelNeedsPassword = true;

  environment.systemPackages = with pkgs; [
    htop
    tmux
  ];

  system.stateVersion = "25.11";
}
