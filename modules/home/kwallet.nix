{ pkgs, ... }:

let
  pamKwalletInit = "${pkgs.kdePackages.kwallet-pam}/libexec/pam_kwallet_init";

  # SDDM/PAM drops kwallet5.socket at login; consume it before graphical apps start.
  # Hyprland exec-once is too late (and races Chrome).
  unlock-kwallet = pkgs.writeShellScript "unlock-kwallet" ''
    set -eu
    sock=/run/user/"$(id -u)"/kwallet5.socket
    for _ in $(${pkgs.coreutils}/bin/seq 1 100); do
      if [ -S "$sock" ]; then
        exec ${pamKwalletInit}
      fi
      ${pkgs.coreutils}/bin/sleep 0.1
    done
    echo >&2 "unlock-kwallet: timed out waiting for $sock (check security.pam.services.*.kwallet)"
    exec ${pamKwalletInit}
  '';
in
{
  # Compositor-agnostic KWallet PAM unlock (Hyprland, niri, …).
  # Requires modules/nixos/desktop.nix (or equivalent) PAM kwallet on the display manager.
  home.packages = with pkgs; [
    kdePackages.kwallet
    kdePackages.kwallet-pam
  ];

  # Plasma's packaged plasma-kwallet-pam.service is tied to kwin and will not start
  # under Hyprland; we do not set systemd.user.services.*.enable (invalid in HM).

  systemd.user.services.unlock-kwallet = {
    Unit = {
      Description = "Unlock KWallet from display-manager PAM credentials";
      Documentation = [ "man:pam_kwallet5(8)" ];
      After = [ "dbus.socket" ];
      Before = [ "graphical-session.target" ];
      PartOf = [ "graphical-session.target" ];
    };
    Service = {
      Type = "oneshot";
      RemainAfterExit = true;
      ExecStart = "${unlock-kwallet}";
    };
    Install = {
      WantedBy = [ "graphical-session-pre.target" ];
    };
  };
}
