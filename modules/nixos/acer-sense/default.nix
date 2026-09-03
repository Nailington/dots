{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.programs.acer-sense;
  acerCtl = pkgs.writeShellScriptBin "acer-ctl" (builtins.readFile ./acer-ctl.sh);
in
{
  # Privileged helper for the DankMaterialShell acerSense plugin.
  # Do not run the plugin's helper/install.sh on NixOS.
  options.programs.acer-sense = {
    enable = mkEnableOption "DMS acerSense acer-ctl helper (NOPASSWD sysfs writes)";
  };

  config = mkIf cfg.enable {
    environment.systemPackages = [ acerCtl ];

    # QML hardcodes `sudo -n /usr/local/bin/acer-ctl`.
    security.sudo.extraRules = [
      {
        groups = [ "wheel" ];
        commands = [
          {
            command = "/usr/local/bin/acer-ctl";
            options = [ "NOPASSWD" ];
          }
        ];
      }
    ];

    systemd.tmpfiles.rules = [
      "d /usr/local/bin 0755 root root -"
      "L+ /usr/local/bin/acer-ctl - - - - ${lib.getExe acerCtl}"
    ];
  };
}
