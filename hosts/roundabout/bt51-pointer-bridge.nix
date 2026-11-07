{ bt51-pointer-bridge }:

{
  systemd.user.services.bt51-pointer-bridge = {
    Unit = {
      Description = "BT5.1 mouse: keyboard iface → virtual pointer (BTN_FORWARD/BTN_BACK for xev/games)";
      Documentation = "https://github.com/KarsMulder/evsieve";
    };
    Service = {
      Type = "simple";
      ExecStart = "${bt51-pointer-bridge}/bin/bt51-pointer-bridge";
      Restart = "always";
      RestartSec = "3s";
    };
    Install.WantedBy = [ "default.target" ];
  };
}
