{ pkgs, self, ... }:

{
  imports = [
    ./hardware-configuration.nix

    ../../modules/nixos/common.nix
    ../../modules/nixos/desktop.nix
    ../../modules/nixos/niri.nix
    # ../../modules/nixos/hyprland.nix  # Hyprland session — enable later / other hosts
    # ../../modules/nixos/plasma.nix  # full Plasma DE — enable later / other hosts
    ../../modules/nixos/gaming.nix
    ../../modules/nixos/networking-tailscale.nix
    ../../modules/nixos/virtualisation.nix
    ../../modules/nixos/hardware/nvidia-prime.nix
    ../../modules/nixos/damx
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

  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  # CachyOS kernel (nvidia-open must support this kernel ABI — verify after upgrades)
  boot.kernelPackages = pkgs.cachyosKernels.linuxPackages-cachyos-latest;
  boot.supportedFilesystems = [ "ntfs" "vfat" ];
  boot.initrd.supportedFilesystems = [ "vfat" ];
  boot.extraModprobeConfig = ''
    options cfg80211 ieee80211_regdom=US
    options kvm_amd nested=1
    options kvm ignore_msrs=1 report_ignored_msrs=0
  '';
  networking.networkmanager.wifi.powersave = false;

  # Prefer ntfs-3g (fuse) over ntfs3 (kernel)
  environment.etc."udisks2/mount_options.conf".text = ''
    [defaults]
    ntfs_defaults=uid=$UID,gid=$GID,windows_names
    ntfs_allow=uid=$UID,gid=$GID,umask,dmask,fmask,locale,norecover,ignore_case,windows_names,compression,nocompression,big_writes
    ntfs:ntfs3_defaults=uid=$UID,gid=$GID
    ntfs:ntfs3_allow=uid=$UID,gid=$GID,umask,dmask,fmask,iocharset,discard,nodiscard,sparse,nosparse,hidden,nohidden,sys_immutable,nosys_immutable,showmeta,noshowmeta,prealloc,noprealloc
    ntfs_drivers=ntfs,ntfs3
  '';

  networking.hostName = "roundabout";
  networking.firewall.allowedTCPPorts = [ 45454 ];

  services.openssh.enable = true;
  services.usbmuxd.enable = true;

  services.flatpak = {
    enable = true;
    packages = [
      "org.vinegarhq.Sober"
      "dev.khcrysalis.PlumeImpactor"
    ];
  };

  services.rockpload.enable = true;

  environment.sessionVariables = {
    __VITE_ADDITIONAL_SERVER_ALLOWED_HOSTS = ".hammerpot.dev";
  };

  # DualSense touchpad ignore + BT5.1 mouse symlinks
  services.udev.extraRules = ''
    # DualSense touchpad - USB and Bluetooth
    ATTRS{name}=="Sony Interactive Entertainment DualSense Wireless Controller Touchpad", ENV{LIBINPUT_IGNORE_DEVICE}="1"
    ATTRS{name}=="DualSense Wireless Controller Touchpad", ENV{LIBINPUT_IGNORE_DEVICE}="1"

    # BT5.1 mouse: stable symlinks under /dev/
    SUBSYSTEM=="input", KERNEL=="event*", ATTRS{name}=="BT5.1 Mouse", SYMLINK+="bt51-mouse"
    SUBSYSTEM=="input", KERNEL=="event*", ATTRS{name}=="BT5.1 Mouse Keyboard", SYMLINK+="bt51-mouse-kbd"
  '';

  environment.etc."libinput/local-overrides.quirks".text = ''
    [BT5.1 Mouse by name]
    MatchName=BT5.1 Mouse
    ModelBouncingKeys=1

    [BT5.1 Mouse by id]
    MatchBus=bluetooth
    MatchVendor=0x25A7
    MatchProduct=0xFA6C
    ModelBouncingKeys=1
  '';

  # BT5.1 Calc/Mail → BTN_FORWARD/BTN_BACK (see home BT bridge service)
  services.udev.extraHwdb =
    let
      mouseKeyboardHwdbMatch = "input:b0005v25A7pFA6C*";
      calculatorScancode = "c0192";
      mailScancode = "c018a";
    in
    ''
      evdev:${mouseKeyboardHwdbMatch}
        KEYBOARD_KEY_${calculatorScancode}=btn_forward
        KEYBOARD_KEY_${mailScancode}=btn_back
    '';

  users.users.potter = {
    isNormalUser = true;
    description = "Potter";
    extraGroups = [
      "networkmanager"
      "wheel"
      "linuwu_sense"
      "fuse"
      "gamemode"
      "docker"
      "input"
      "kvm"
      "libvirtd"
    ];
    # KDE apps (Dolphin, Ark, games, kwallet, …) → modules/home/kde-apps.nix
  };

  programs.coolercontrol.enable = true;

  programs.damx = {
    enable = true;
    linuwuSenseForce = "nitrov4";
  };

  hardware.nvidia.prime = {
    sync.enable = true;
    amdgpuBusId = "PCI:101:0:0";
    nvidiaBusId = "PCI:1:0:0";
  };

  environment.systemPackages = with pkgs; [
    evtest
    iw
    wavemon
    acpi
    lm_sensors
    nbfc-linux
    self.packages.${pkgs.system}.nixos-remote-install
  ];

  swapDevices = [
    {
      device = "/swapfile";
      size = 32 * 1024;
    }
  ];

  systemd.sleep.settings.Sleep = {
    AllowHibernation = false;
    AllowSuspendThenHibernate = false;
    AllowHybridSleep = false;
  };
  boot.kernelParams = [ "nohibernate" ];

  # Lid close: do not suspend (keeps host + QEMU alive during long macOS installs)
  services.logind.settings.Login = { };

  system.stateVersion = "25.11";
}
