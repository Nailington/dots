# From crontab.txt. Jobs source /etc/profile so PATH matches a login shell
# (cron's default PATH is only system-path bin/sbin, not HM/user profiles).
{ pkgs, ... }:

{
  services.cron = {
    enable = true;
    systemCronJobs = [
      "TZ=America/New_York"
      # "53 9 * * * potter . /etc/profile; echo \"$PATH\" > /home/potter/test.txt"
      "0 9-16 * * 1-5 potter . /etc/profile; cd /mnt/storage/auto-rob && npm start >> /var/log/auto-rob.log 2>&1"
      "30 9-16 * * 1-5 potter . /etc/profile; cd /mnt/storage/auto-rob && npm start >> /var/log/auto-rob.log 2>&1"
    ];
  };

  environment.systemPackages = [ pkgs.nodejs ];

  systemd.tmpfiles.rules = [
    "f /var/log/auto-rob.log 0644 potter users -"
  ];
}
