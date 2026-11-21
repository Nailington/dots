{ pkgs, ... }:

# Makes the Pi 5 appear as a USB security key (FIDO2/U2F over HID, plus PIV,
# OpenPGP and OATH over CCID) on whatever computer its USB-C port is plugged
# into. Software only: private keys are plain files in /var/lib/virtual-yubikey.
# Upstream: https://github.com/qpernil/virtual-yubikey
#
# Approve a registration/login (user presence) from custard while the host is
# waiting, within 30 seconds:
#   sudo -u virtual-yubikey virtual-yubikey-touch
let
  stateDirectory = "/var/lib/virtual-yubikey";
  runtimeDirectory = "/run/virtual-yubikey";

  # The worker insists on display and button handles. No display HAT is fitted,
  # so /dev/null stands in for the SPI display (its init failure is logged and
  # ignored) and the GPIO lines are unused header pins with pull-ups, so the
  # buttons read as never pressed and touch only comes from the helper. This
  # drives header GPIO 24, 25 and 27 low and reads 13 and 16: keep them free.
  profile = pkgs.writeText "virtual-yubikey.toml" ''
    schema = 1
    name = "virtual-yubikey"
    functionfs_mount = "/dev/ffs-virtual-yubikey"

    [worker]
    command = "${pkgs.virtual-yubikey}/bin/virtual-yubikey-worker"
    arguments = ["--serial", "12345678", "--log-level", "info"]
    run_as = "virtual-yubikey"
    readiness_timeout_ms = 10000
    state_directory = "${stateDirectory}"
    runtime_directory = "${runtimeDirectory}"

    [[resources]]
    type = "character-device"
    name = "display-spi"
    path = "/dev/null"
    access = "read-write"

    [[resources]]
    type = "gpio-lines"
    name = "display-control"
    path = "/dev/gpiochip0"
    offsets = [25, 27, 24]
    direction = "output"
    initial_values = [false, false, false]

    [[resources]]
    type = "gpio-lines"
    name = "touch-button"
    path = "/dev/gpiochip0"
    offsets = [13]
    direction = "input"
    active_low = true
    bias = "pull-up"
    edge = "both"

    [[resources]]
    type = "gpio-lines"
    name = "reconnect-button"
    path = "/dev/gpiochip0"
    offsets = [16]
    direction = "input"
    active_low = true
    bias = "pull-up"
    edge = "both"
  '';
in
{
  # Put the USB-C port in device mode (it is the Pi's power port, never a host
  # port). Takes effect after a reboot; the unit below waits for the controller.
  hardware.raspberry-pi.config.all.dt-overlays.dwc2 = {
    enable = true;
    params.dr_mode = {
      enable = true;
      value = "peripheral";
    };
  };

  # Preloaded so the supervisor never needs to run modprobe.
  boot.kernelModules = [ "libcomposite" "usb_f_fs" ];

  users.groups.virtual-yubikey = { };
  users.users.virtual-yubikey = {
    isSystemUser = true;
    group = "virtual-yubikey";
    description = "Virtual YubiKey worker";
  };

  environment.systemPackages = [ pkgs.virtual-yubikey ];

  systemd.services.virtual-yubikey = {
    description = "Virtual YubiKey USB gadget";
    wantedBy = [ "multi-user.target" ];
    after = [ "local-fs.target" "systemd-modules-load.service" ];
    # No UDC until the dwc2 overlay is active after a reboot; skip quietly.
    unitConfig = {
      ConditionPathExistsGlob = "/sys/class/udc/*";
      StartLimitIntervalSec = 60;
      StartLimitBurst = 5;
    };
    serviceConfig = {
      Type = "simple";
      ExecStart = "${pkgs.virtual-yubikey.supervisor}/bin/usb-gadget-supervisor --profile ${profile}";
      ExecReload = "${pkgs.coreutils}/bin/kill -HUP $MAINPID";
      Restart = "on-failure";
      RestartSec = "2s";
      KillMode = "mixed";
      TimeoutStopSec = "10s";
    };
  };
}
