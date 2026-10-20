# Jobs source /etc/profile so the agent harness CLIs are on PATH
# (cron's default PATH is only system-path bin/sbin, not HM/user profiles).
{ pkgs, ... }:

{
  services.cron = {
    enable = true;
    systemCronJobs = [
      "TZ=America/New_York"
      # "53 9 * * * potter . /etc/profile; echo \"$PATH\" > /home/potter/test.txt"
      "0 9,12,16 * * 1-5 potter . /etc/profile; AUTO_ROB_WORKSPACE=/mnt/storage/auto-rob ${pkgs.auto-rob}/bin/auto-rob >> /var/log/auto-rob.log 2>&1"
      "30 9,16 * * 1-5 potter . /etc/profile; AUTO_ROB_WORKSPACE=/mnt/storage/auto-rob ${pkgs.auto-rob}/bin/auto-rob >> /var/log/auto-rob.log 2>&1"
    ];
  };

  systemd.tmpfiles.rules = [
    "f /var/log/auto-rob.log 0644 potter users -"
  ];
}
