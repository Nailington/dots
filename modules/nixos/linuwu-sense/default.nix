{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.programs.linuwu-sense;

  linuwuSenseModule = config.boot.kernelPackages.callPackage ./package.nix { };

  # Same names as linuwu_sense module_param() (underscores).
  modprobeByForce = {
    nitrov4 = "options linuwu_sense nitro_v4=1";
    predatorv4 = "options linuwu_sense predator_v4=1";
    enableall = "options linuwu_sense enable_all=1";
  };
in
{
  options.programs.linuwu-sense = {
    enable = mkEnableOption "Linuwu Sense kernel module (Acer Nitro/Predator sysfs)";

    force = mkOption {
      type = types.nullOr (types.enum [ "nitrov4" "predatorv4" "enableall" ]);
      default = null;
      description = ''
        Force linuwu_sense module parameters at load time — the same effect as
        DAMX "Load with nitrov4 / predatorv4 / enableall", but applied before
        the module probes hardware.

        Set to nitrov4 if your laptop is not in the driver's DMI table but works
        with Nitro Sense v4 overrides.
      '';
    };
  };

  config = mkIf cfg.enable {
    boot.extraModulePackages = [ linuwuSenseModule ];
    boot.kernelModules = [ "linuwu_sense" ];

    boot.extraModprobeConfig = mkIf (cfg.force != null) modprobeByForce.${cfg.force};

    users.groups.linuwu_sense = { };

    systemd.services.linuwu-sense-unload = {
      description = "Unload linuwu_sense at shutdown";
      wantedBy = [ "multi-user.target" ];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        ExecStop = "${pkgs.kmod}/bin/rmmod linuwu_sense";
      };
    };
  };
}
