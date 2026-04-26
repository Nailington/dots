{ config, pkgs, ... }:

{
  imports = [
    ./hardware-configuration.nix
  ];

  # NTFS "Acer" partition - same permission style as Dolphin (uid/gid, dmask/fmask)
  # nofail + 10s timeout: boot proceeds if partition missing (e.g. dual-boot, disk not present)
  # Get UUID with: blkid -s UUID -o value /dev/nvmeXn1pN
#  fileSystems."/run/media/potter/Acer" = {
#    device = "/dev/disk/by-uuid/122AEF932AEF7261";
#    fsType = "ntfs-3g";
#    options = [
#      "uid=${toString config.users.users.potter.uid}"
#      "gid=${toString config.users.groups.users.gid}"
#      "dmask=0022"
#      "fmask=0133"
#      "windows_names"
#      "nofail"
#      "x-systemd.device-timeout=10s"
#    ];
#  };

  # Bootloader
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

#  # Use default kernel (nvidia-open doesn't support 6.19 yet)
#  boot.kernelPackages = pkgs.linuxPackages;
  # CachyOS kernel (nvidia-open must support this kernel ABI — verify after upgrades)
  boot.kernelPackages = pkgs.cachyosKernels.linuxPackages-cachyos-latest;
  boot.supportedFilesystems = [ "ntfs" ];
  boot.extraModprobeConfig = "options cfg80211 ieee80211_regdom=US";
  networking.networkmanager.wifi.powersave = false;

  # Prefer ntfs-3g (fuse) over ntfs3 (kernel) - ntfs3 rejects dirty volumes by default
  environment.etc."udisks2/mount_options.conf".text = ''
    [defaults]
    ntfs_defaults=uid=$UID,gid=$GID,windows_names
    ntfs_allow=uid=$UID,gid=$GID,umask,dmask,fmask,locale,norecover,ignore_case,windows_names,compression,nocompression,big_writes
    ntfs:ntfs3_defaults=uid=$UID,gid=$GID
    ntfs:ntfs3_allow=uid=$UID,gid=$GID,umask,dmask,fmask,iocharset,discard,nodiscard,sparse,nosparse,hidden,nohidden,sys_immutable,nosys_immutable,showmeta,noshowmeta,prealloc,noprealloc
    ntfs_drivers=ntfs,ntfs3
  '';

  # Networking
  networking.hostName = "nixos";
  networking.networkmanager.enable = true;

  # SSH server (opens port 22 in firewall automatically)
  services.openssh.enable = true;
  services.davfs2.enable = true;
  services.usbmuxd.enable = true;
  virtualisation.docker.enable = true;
  services.flatpak = {
    enable = true;
    packages = [
      "org.vinegarhq.Sober"
    ];
  };

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
  environment.sessionVariables = {
    NIXOS_OZONE_WL = "1";
    LIBVA_DRIVER_NAME = "nvidia";  # Use NVIDIA for VA-API (hardware encoding)
    NVD_BACKEND = "direct";        # Direct NVDEC/NVENC access
    FUSERMOUNT_PROG = "${pkgs.fuse3}/bin/fusermount3";  # AppImage FUSE mount
    __GL_SHADER_DISK_CACHE_SKIP_CLEANUP = "1"; # nvidia shader cache moment
    __VITE_ADDITIONAL_SERVER_ALLOWED_HOSTS = ".hammerpot.dev"; # Allow my domain for Vite 
  };

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

  # Disable DualSense/PS5 controller touchpad acting as mouse
  services.udev.extraRules = ''
    # DualSense touchpad - USB and Bluetooth
    ATTRS{name}=="Sony Interactive Entertainment DualSense Wireless Controller Touchpad", ENV{LIBINPUT_IGNORE_DEVICE}="1"
    ATTRS{name}=="DualSense Wireless Controller Touchpad", ENV{LIBINPUT_IGNORE_DEVICE}="1"
  '';

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
    extraGroups = [ "networkmanager" "wheel" "linuwu_sense" "fuse" "gamemode" "docker" ];  # fuse: AppImage / FUSE mounts
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
  programs.kdeconnect.enable = true;

  # Steam
  programs.steam = {
    enable = true;
    remotePlay.openFirewall = true;
    dedicatedServer.openFirewall = true;
    extraPackages = with pkgs; [ gamemode ];
    protontricks.enable = true; 
  };

#  environment.variables.__GL_SHADER_DISK_CACHE_SKIP_CLEANUP = "1";

  # Reduce scheduler and memory latency for Proton/Wine games
#  boot.kernel.sysctl = {
#    "vm.compaction_proactiveness" = 0;       # Disable proactive memory compaction (causes latency spikes)
#    "vm.swappiness" = 10;
#    "vm.min_free_kbytes" = 524288;           # 512MB - trigger background reclaim earlier to avoid direct reclaim stalls
#    "vm.watermark_boost_factor" = 0;         # Prevent over-aggressive reclaim after a spike
#    "vm.watermark_scale_factor" = 125;       # Wider watermark gap for smoother background reclaim
#    "kernel.sched_min_granularity_ns" = 800000;
#    "kernel.sched_wakeup_granularity_ns" = 500000;
#  };

#  # Defer THP defrag asynchronously to prevent game thread stalls
#  systemd.tmpfiles.rules = [
#    "w /sys/kernel/mm/transparent_hugepage/defrag - - - - defer+madvise"
#  ];


  # Feral GameMode - CPU/GPU optimisation daemon for games

  programs.gamemode = {
    enable = true;
    enableRenice = true;
    settings.general.renice = 10;
    settings.general.inhibit_screensaver = 1;
    settings.cpu.park_cores = "no";
    settings.cpu.pin_cores = "no";
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
    pkgs.gamemode.lib  # exposes libgamemode.so to /run/current-system/sw/lib
    iw              # WiFi configuration tool
    wavemon         # WiFi signal monitor TUI
    usbutils        # lsusb and USB debugging tools
    acpi            # Battery status, thermal info
    e2fsprogs       # ext2/ext3/ext4 tools (mkfs, fsck, resize2fs, etc.)
    fuse3           # fusermount3 for FUSE mounts
    vim
    git
    wget
    curl
    nh
    lm_sensors    # Hardware sensor monitoring
    nbfc-linux    # Notebook fan control
  ];

  # Graphics
  hardware.graphics = {
    enable = true;
    extraPackages = with pkgs; [
      nvidia-vaapi-driver  # NVENC via VA-API for OBS/FFmpeg
    ];
  };

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
  systemd.sleep.settings.Sleep = {
    AllowHibernation = false;
    AllowSuspendThenHibernate = false;
    AllowHybridSleep = false;
  };
  boot.kernelParams = [ "nohibernate" ];

  # Clipboard manager for rofi (user systemd unit + systemPackages); see nixpkgs modules/services/misc/greenclip.nix
  #services.greenclip.enable = true;

  # Tailscale VPN
  services.tailscale = {
    enable = true;
    useRoutingFeatures = "both";
    # UDP 41641: helps peers connect directly when not only via DERP
    openFirewall = true;
  };

  # Allow any TCP/UDP port you listen on to be reached from the tailnet.
  # Without this, NixOS firewall only allows reply traffic; inbound to e.g. 8080 is dropped.
  networking.firewall.trustedInterfaces = [ config.services.tailscale.interfaceName ];

  # Mullvad VPN (requires systemd-resolved)
  services.resolved.enable = true;
  services.mullvad-vpn = {
    enable = true;
    package = pkgs.mullvad-vpn;  # GUI app (default is CLI-only mullvad)
  };

  # Enable KWallet PAM auto-unlock (works for both KDE and Hyprland via SDDM)
  security.pam.services.sddm.kwallet.enable = true;

  # Flakes + nix-cachyos-kernel binary cache (Hydra/Attic; apply before first kernel switch)
  nix.settings = {
    experimental-features = [ "nix-command" "flakes" ];
    extra-substituters = [ "https://attic.xuyh0120.win/lantian" ];
    extra-trusted-public-keys = [ "lantian:EeAUQ+W+6r7EtwnmYjeVwx5kOGEBpjlBfPlzGlTNvHc=" ];
  };

  # System state version - don't change unless you know what you're doing
  system.stateVersion = "25.11";
}

