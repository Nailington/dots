{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.programs.damx;

  # Kernel module for Linuwu Sense
  linuwuSenseModule = config.boot.kernelPackages.callPackage ./linuwu-sense.nix { };

  # Same names as linuwu_sense module_param() in Linuwu-Sense (underscores).
  linuwuSenseModprobeByForce = {
    nitrov4 = "options linuwu_sense nitro_v4=1";
    predatorv4 = "options linuwu_sense predator_v4=1";
    enableall = "options linuwu_sense enable_all=1";
  };
  
  # DAMX Daemon package
  damxDaemon = pkgs.callPackage ./damx-daemon.nix { };
  
  # DAMX GUI package  
  damxGui = pkgs.callPackage ./damx-gui.nix { };

in {
  options.programs.damx = {
    enable = mkEnableOption "DAMX - Div Acer Manager Max for Acer laptops";
    
    package = mkOption {
      type = types.package;
      default = damxGui;
      description = "The DAMX GUI package to use";
    };

    linuwuSenseForce = mkOption {
      type = types.nullOr (types.enum [ "nitrov4" "predatorv4" "enableall" ]);
      default = null;
      description = ''
        Force Linuwu-Sense (linuwu_sense) module parameters at load time — the same
        effect as DAMX "Load with nitrov4 / predatorv4 / enableall", but permanent
        and applied before the module probes hardware (avoids failed auto-detection
        and long retry loops).

        Set to nitrov4 if your laptop is not in the driver's DMI table but works
        with Nitro Sense v4 overrides.
      '';
    };
  };

  config = mkIf cfg.enable {
    # Install the kernel module
    boot.extraModulePackages = [ linuwuSenseModule ];
    
    # Load the module at boot
    boot.kernelModules = [ "linuwu_sense" ];

    boot.extraModprobeConfig = mkIf (cfg.linuwuSenseForce != null) (
      linuwuSenseModprobeByForce.${cfg.linuwuSenseForce}
    );
    
    # Blacklist conflicting acer_wmi module
#    boot.blacklistedKernelModules = [ "acer_wmi" ];
    
    # Create linuwu_sense group
    users.groups.linuwu_sense = { };
    
    # Install daemon and GUI
    environment.systemPackages = [
      damxDaemon
      cfg.package
    ];
    
    # Systemd service for the daemon
    systemd.services.damx-daemon = {
      description = "DAMX Daemon for Acer laptop control";
      wantedBy = [ "multi-user.target" ];
      after = [ "systemd-modules-load.service" ];
      path = [ pkgs.kmod pkgs.sudo pkgs.coreutils pkgs.util-linux ];
      
      serviceConfig = {
        Type = "simple";
        ExecStart = "${damxDaemon}/bin/DAMX-Daemon";
        Restart = "on-failure";
        RestartSec = 5;
      };
    };
    
    # Systemd service to unload module cleanly at shutdown
    systemd.services.linuwu-sense-unload = {
      description = "Unload linuwu_sense at shutdown";
      wantedBy = [ "multi-user.target" ];
      
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        ExecStop = "${pkgs.kmod}/bin/rmmod linuwu_sense";
      };
    };
    
    # Set permissions on sysfs entries via tmpfiles
    systemd.tmpfiles.rules = [
      # These will be created after the module loads
      # The actual paths depend on whether it's nitro_sense or predator_sense
      "d /run/damx 0755 root linuwu_sense -"
    ];
  };
}
