{ config, pkgs, ... }:

{
  imports = [
    ./hardware-configuration.nix
  ];

  # Bootloader
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  # Use latest kernel
  boot.kernelPackages = pkgs.linuxPackages_latest;

  # Networking
  networking.hostName = "nixos";
  networking.networkmanager.enable = true;

  # Timezone & Locale
  time.timeZone = "America/New_York";
  i18n.defaultLocale = "en_US.UTF-8";
  i18n.extraLocaleSettings = {
    LC_ADDRESS = "en_US.UTF-8";
    LC_IDENTIFICATION = "en_US.UTF-8";
    LC_MEASUREMENT = "en_US.UTF-8";
    LC_MONETARY = "en_US.UTF-8";
    LC_NAME = "en_US.UTF-8";
    LC_NUMERIC = "en_US.UTF-8";
    LC_PAPER = "en_US.UTF-8";
    LC_TELEPHONE = "en_US.UTF-8";
    LC_TIME = "en_US.UTF-8";
  };

  # X11 & Desktop Environment
  services.xserver.enable = true;
  services.displayManager.sddm.enable = true;
  services.displayManager.sddm.settings.General.Numlock = "on";
  services.desktopManager.plasma6.enable = true;

  services.xserver.xkb = {
    layout = "us";
    variant = "";
  };

  # Hyprland
  programs.hyprland.enable = true;
  environment.sessionVariables.NIXOS_OZONE_WL = "1";

  # Printing
  services.printing.enable = true;

  # Audio (PipeWire)
  services.pulseaudio.enable = false;
  security.rtkit.enable = true;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
  };

  # Bluetooth (used by both KDE and Blueman)
  hardware.bluetooth.enable = true;
  hardware.bluetooth.powerOnBoot = true;
  services.blueman.enable = true;
  
  # Use a different MAC address than Windows to avoid pairing conflicts when dual-booting
  hardware.bluetooth.settings = {
    General = {
      Privacy = "device";
      JustWorksRepairing = "always";
      FastConnectable = true;
    };
  };

  # User account
  users.users.potter = {
    isNormalUser = true;
    description = "Potter";
    extraGroups = [ "networkmanager" "wheel" "linuwu_sense" ];
    packages = with pkgs; [
      kdePackages.kate
      kdePackages.kwallet
      kdePackages.kwallet-pam
      # KDE Games
      kdePackages.kmines
      kdePackages.kpat
      kdePackages.ksudoku
      kdePackages.knetwalk
      kdePackages.kapman
      kdePackages.kblocks
      kdePackages.kbounce
      kdePackages.kollision
      kdePackages.kolf
    ];
  };

  # Default shell
  programs.zsh.enable = true;
  users.defaultUserShell = pkgs.zsh;

  # Firefox
  programs.firefox.enable = true;

  # Steam
  programs.steam = {
    enable = true;
    remotePlay.openFirewall = true;
    dedicatedServer.openFirewall = true;
  };

  # CoolerControl - cooling device control
  programs.coolercontrol = {
    enable = true;
  };

  # DAMX - Div Acer Manager Max (NitroSense for Linux)
  programs.damx.enable = true;

  # Allow unfree packages
  nixpkgs.config.allowUnfree = true;

  # System packages (minimal - most go in home-manager)
  environment.systemPackages = with pkgs; [
    vim
    git
    wget
    curl
    nh
    lm_sensors    # Hardware sensor monitoring
    nbfc-linux    # Notebook fan control
  ];

  # Graphics
  hardware.graphics.enable = true;

  # NVIDIA Configuration
  services.xserver.videoDrivers = [ "nvidia" ];

  hardware.nvidia = {
    modesetting.enable = true;
    powerManagement.enable = true;  # Helps with sleep/wake
    powerManagement.finegrained = false;
    open = true;
    nvidiaSettings = true;
    package = config.boot.kernelPackages.nvidiaPackages.stable;
  };

  hardware.nvidia.prime = {
    sync.enable = true;
    amdgpuBusId = "PCI:101:0:0";
    nvidiaBusId = "PCI:1:0:0";
  };

  # Swap
  swapDevices = [{
    device = "/swapfile";
    size = 32 * 1024;
  }];

  # Disable hibernation completely
  systemd.sleep.extraConfig = ''
    AllowHibernation=no
    AllowSuspendThenHibernate=no
    AllowHybridSleep=no
  '';
  boot.kernelParams = [ "nohibernate" ];

  # Tailscale VPN
  services.tailscale = {
    enable = true;
    useRoutingFeatures = "both";
  };

  # Enable KWallet PAM auto-unlock (works for both KDE and Hyprland via SDDM)
  security.pam.services.sddm.kwallet.enable = true;

  # Enable flakes
  nix.settings.experimental-features = [ "nix-command" "flakes" ];

  # System state version - don't change unless you know what you're doing
  system.stateVersion = "25.11";
}

