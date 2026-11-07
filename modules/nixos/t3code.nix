{ config, pkgs, ... }:

{
  # Keep T3's user service running at boot and after the last logout.
  users.users.potter.linger = true;
  # HM supplies only the host-specific drop-in. T3 owns the writable base unit
  # so `t3 service restart` can regenerate it after an application update.
  systemd.services.t3code-install = {
    description = "Install and restart Potter's T3 Code user service";
    wantedBy = [ "multi-user.target" ];
    wants = [ "network-online.target" ];
    requires = [ "home-manager-potter.service" "linger-users.service" ];
    after = [
      "home-manager-potter.service"
      "linger-users.service"
      "systemd-user-sessions.service"
      "network-online.target"
    ];
    restartTriggers = [ config.home-manager.users.potter.home.activationPackage ];
    # A first install downloads and extracts T3's standalone runtime.
    path = [ pkgs.systemd pkgs.gnutar pkgs.gzip ];
    environment = {
      HOME = config.users.users.potter.home;
      # Keep service installation on the existing server home, separate from desktop.
      T3CODE_HOME = "${config.users.users.potter.home}/.t3";
    };
    serviceConfig = {
      Type = "oneshot";
      User = "potter";
      RemainAfterExit = true;
      # Wait for the user manager on first boot; enabling linger starts it asynchronously.
      ExecStartPre = "+${pkgs.runtimeShell} -c '${pkgs.systemd}/bin/systemctl start user@$(${pkgs.coreutils}/bin/id -u potter).service'";
    };
    script = ''
      export XDG_RUNTIME_DIR="/run/user/$(id -u)"
      # A switch can restart NetworkManager after network-online.target was
      # reached. Allow DNS/connectivity to recover before giving up the install.
      for attempt in {1..6}; do
        if ${pkgs.t3code}/bin/t3 service install; then
          break
        fi
        if [ "$attempt" -eq 6 ]; then
          echo "T3 Code service installation failed after 6 attempts." >&2
          exit 1
        fi
        echo "T3 Code service installation failed; retrying in 15 seconds ($attempt/6)." >&2
        sleep 15
      done
      ${pkgs.t3code}/bin/t3 service restart
    '';
  };
}
