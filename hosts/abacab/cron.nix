# From crontab.txt (PATH omitted — NixOS /etc/crontab already uses system-path).
# Commented lines ignored. auto-rob lives on the data disk.
{ pkgs, ... }:

{
  services.cron = {
    enable = true;
    systemCronJobs = [
      "TZ=America/New_York"
      "0 9-16 * * 1-5 potter cd /mnt/storage/auto-rob && npm start >> /var/log/auto-rob.log 2>&1"
      "30 9-16 * * 1-5 potter cd /mnt/storage/auto-rob && npm start >> /var/log/auto-rob.log 2>&1"
    ];
  };

  environment.systemPackages = [ pkgs.nodejs ];

  systemd.tmpfiles.rules = [
    "f /var/log/auto-rob.log 0644 potter users -"
  ];
}
