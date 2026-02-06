{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.programs.damx;
  
  # Kernel module for Linuwu Sense
  linuwuSenseModule = config.boot.kernelPackages.callPackage ./linuwu-sense.nix { };
  
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
  };

  config = mkIf cfg.enable {
    # Install the kernel module
    boot.extraModulePackages = [ linuwuSenseModule ];
    
    # Load the module at boot
    boot.kernelModules = [ "linuwu_sense" ];
    
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
