{ config, lib, pkgs, self, ... }:

{
  imports = [
    ./hardware-configuration.nix

    ../../modules/nixos/common.nix
    ../../modules/nixos/desktop.nix
    ../../modules/nixos/niri.nix
    # ../../modules/nixos/hyprland.nix  # Hyprland + SDDM — enable later / other hosts
    # ../../modules/nixos/plasma.nix  # Plasma + SDDM — enable later / other hosts
    ../../modules/nixos/gaming.nix
    ../../modules/nixos/networking-tailscale.nix
    ../../modules/nixos/virtualisation.nix
    ../../modules/nixos/hardware/nvidia-prime.nix
    ../../modules/nixos/linuwu-sense
    ../../modules/nixos/damx
    ../../modules/nixos/acer-sense
  ];

  # Acer Windows partition: match Dolphin's live ntfs mount (potter:users, mode 0777).
  # Try at boot; missing devices or mount failures must not block startup.
  fileSystems."/run/media/potter/Acer" = {
    device = "/dev/disk/by-uuid/122AEF932AEF7261";
    fsType = "ntfs";
    noCheck = true;
    options = [
      "rw"
      "nosuid"
      "nodev"
      "relatime"
      "uid=1000"
      "gid=100"
      "umask=000"
      "iocharset=utf8"
      "case_sensitive"
      "errors=continue"
      "mft_zone_multiplier=1"
      "windows_names"
      "native_symlink=raw"
      "symlink=wsl"
      "nofail"
      "x-systemd.device-timeout=10s"
      "x-systemd.mount-timeout=10s"
    ];
  };

  # Build custard's ARM image using QEMU user-mode emulation.
  boot.binfmt.emulatedSystems = [ "aarch64-linux" ];

  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  # CachyOS kernel (nvidia-open must support this kernel ABI — verify after upgrades)
  boot.kernelPackages = pkgs.cachyosKernels.linuxPackages-cachyos-latest.extend (_: kernelPackages: {
    # VMware copies modules without certificates. Sign after stripping until
    # its upstream installer supports nixpkgs' module certificate generation.
    vmware = kernelPackages.vmware.overrideAttrs (old: {
      postFixup = (old.postFixup or "") + ''
        for module in vmmon vmnet; do
          ${lib.getExe pkgs.buildPackages.kmodigest} \
            "$out/lib/modules/${kernelPackages.kernel.modDirVersion}/misc/$module.ko"
        done
      '';
    });
  });
  boot.supportedFilesystems = [ "ntfs" "vfat" ];
  boot.initrd.supportedFilesystems = [ "vfat" ];
  boot.extraModprobeConfig = ''
    options cfg80211 ieee80211_regdom=US
    options kvm_amd nested=1
    options kvm ignore_msrs=1 report_ignored_msrs=0
  '';
  networking.networkmanager.wifi.powersave = false;

  # Prefer ntfs (the kernel driver on CachyOS >= 7.1) over ntfs3.
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

  # Check before filter/INPUT: Tailscale accepts peers before nixos-fw runs.
  networking.firewall.extraCommands = ''
    ip46tables -t mangle -N cliproxy-home 2>/dev/null || true
    ip46tables -t mangle -F cliproxy-home
    iptables -t mangle -A cliproxy-home -i ${config.services.tailscale.interfaceName} \
      -s 100.87.123.57 -d 100.67.7.114 -j RETURN
    ip46tables -t mangle -A cliproxy-home -j DROP
    ip46tables -t mangle -I INPUT 1 -p tcp --dport 8320 -j cliproxy-home
  '';
  networking.firewall.extraStopCommands = ''
    ip46tables -t mangle -D INPUT -p tcp --dport 8320 -j cliproxy-home 2>/dev/null || true
    ip46tables -t mangle -F cliproxy-home 2>/dev/null || true
    ip46tables -t mangle -X cliproxy-home 2>/dev/null || true
  '';

  users.groups.cliproxy-home = { };
  users.users.cliproxy-home = {
    isSystemUser = true;
    group = "cliproxy-home";
  };
  age.secrets.roundabout-home-proxy = {
    file = ../../secrets/roundabout-home-proxy.age;
    owner = "cliproxy-home";
    group = "cliproxy-home";
    mode = "0400";
  };
  systemd.services.cliproxy-home = {
    description = "Provider CONNECT proxy for Crack's account-policy relay";
    wantedBy = [ "multi-user.target" ]; # Start at boot; manual stop lasts until reboot.
    wants = [ "network-online.target" "tailscaled.service" ];
    after = [ "network-online.target" "tailscaled.service" "tailscaled-autoconnect.service" "firewall.service" ];
    requires = [ "firewall.service" ];
    path = [ pkgs.tailscale ];
    preStart = ''
      tailscale wait --timeout=0
      tailscale ip --assert=100.67.7.114
    '';
    serviceConfig = {
      Type = "simple";
      User = "cliproxy-home";
      Group = "cliproxy-home";
      ExecStart = "${lib.getExe pkgs.nodejs} ${./home_proxy.mjs} --listen 100.67.7.114 --port 8320 --token-file ${config.age.secrets.roundabout-home-proxy.path} --allow-client 100.87.123.57";
      Restart = "on-failure";
      RestartSec = "5s";
      TimeoutStartSec = "infinity";
      TimeoutStopSec = "10s";
      UMask = "0077";
      NoNewPrivileges = true;
      CapabilityBoundingSet = "";
      PrivateTmp = true;
      PrivateDevices = true;
      ProtectSystem = "strict";
      ProtectHome = true;
      ProtectKernelTunables = true;
      ProtectKernelModules = true;
      ProtectControlGroups = true;
      RestrictSUIDSGID = true;
      RestrictRealtime = true;
      RestrictAddressFamilies = [ "AF_INET" "AF_INET6" "AF_UNIX" "AF_NETLINK" ];
    };
  };

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

    # QEMU usb-host + raw USB disks for osx-kvm (potter is in kvm)
    SUBSYSTEM=="usb", MODE="0664", GROUP="kvm"
    SUBSYSTEM=="block", SUBSYSTEMS=="usb", GROUP="kvm", MODE="0660"
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

  programs.linuwu-sense = {
    enable = true;
    force = "nitrov4";
  };

  programs.damx.enable = true;
  programs.acer-sense.enable = true;

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
    (pkgs.writeShellApplication {
      name = "home-proxy";
      runtimeInputs = [ pkgs.systemd pkgs.sudo ];
      text = ''
        case "''${1:-status}" in
          on|start) sudo systemctl start cliproxy-home.service ;;
          off|stop) sudo systemctl stop cliproxy-home.service ;;
          restart) sudo systemctl restart cliproxy-home.service ;;
          status) systemctl status cliproxy-home.service ;;
          *) echo 'Usage: home-proxy {on|off|restart|status}' >&2; exit 2 ;;
        esac
      '';
    })
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

  # Stay reachable on AC, including when a closed-lid HDMI connection drops.
  # Lock instead of suspending; retain lid-close suspend when undocked on battery.
  services.logind.settings.Login = {
    HandleLidSwitch = "suspend";
    HandleLidSwitchExternalPower = "lock";
    HandleLidSwitchDocked = "lock";
    # DMS owns idle locking; logind must not put locked sessions to sleep.
    IdleAction = "ignore";
  };

  system.stateVersion = "25.11";
}
