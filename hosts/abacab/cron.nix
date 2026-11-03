# Jobs source /etc/profile so the agent harness CLIs are on PATH
# (cron's default PATH is only system-path bin/sbin, not HM/user profiles).
{ pkgs, ... }:

{
  services.cron = {
    enable = true;
    systemCronJobs = [
      "TZ=America/New_York"
      # "53 9 * * * potter . /etc/profile; echo \"$PATH\" > /home/potter/test.txt"
      # Use the desktop app's default workspace, with its saved strategy and notes.
      "0 9,12,16 * * 1-5 potter . /etc/profile; ${pkgs.auto-rob}/bin/auto-rob >> /var/log/auto-rob.log 2>&1"
      "30 9,16 * * 1-5 potter . /etc/profile; ${pkgs.auto-rob}/bin/auto-rob >> /var/log/auto-rob.log 2>&1"
    ];
  };

  systemd.tmpfiles.rules = [
    "f /var/log/auto-rob.log 0644 potter users -"
  ];
}
