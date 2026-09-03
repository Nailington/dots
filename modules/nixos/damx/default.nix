{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.programs.damx;

  damxDaemon = pkgs.callPackage ./damx-daemon.nix { };
  damxGui = pkgs.callPackage ./damx-gui.nix { };
in
{
  options.programs.damx = {
    enable = mkEnableOption "DAMX - Div Acer Manager Max GUI and daemon";

    package = mkOption {
      type = types.package;
      default = damxGui;
      description = "The DAMX GUI package to use";
    };
  };

  config = mkIf cfg.enable {
    # Daemon writes under /run/damx; group is also created by programs.linuwu-sense.
    users.groups.linuwu_sense = { };

    environment.systemPackages = [
      damxDaemon
      cfg.package
    ];

    systemd.services.damx-daemon = {
      description = "DAMX Daemon for Acer laptop control";
      wantedBy = [ "multi-user.target" ];
      after = [ "systemd-modules-load.service" ];
      path = [
        pkgs.kmod
        pkgs.sudo
        pkgs.coreutils
        pkgs.util-linux
      ];
      serviceConfig = {
        Type = "simple";
        ExecStart = "${damxDaemon}/bin/DAMX-Daemon";
        Restart = "on-failure";
        RestartSec = 5;
      };
    };

    systemd.tmpfiles.rules = [
      "d /run/damx 0755 root linuwu_sense -"
    ];
  };
}
