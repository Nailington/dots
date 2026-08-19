{ pkgs, ... }:

let
  # hwdb sends BTN_FORWARD/BTN_BACK on the keyboard BT HID node; clone onto a virtual pointer.
  # Requires NixOS udev symlink bt51-mouse-kbd and user in `input`.
  bt51-pointer-bridge = pkgs.writeShellScriptBin "bt51-pointer-bridge" ''
    set -eu
    dev=/dev/bt51-mouse-kbd
    echo >&2 "bt51-pointer-bridge: waiting for ''${dev} (connect BT mouse or plug dongle)…"
    while [ ! -e "''${dev}" ] || [ ! -c "''${dev}" ] || [ ! -r "''${dev}" ]; do
      ${pkgs.coreutils}/bin/sleep 2
    done
    echo >&2 "bt51-pointer-bridge: ''${dev} ready, starting evsieve."
    exec ${pkgs.evsieve}/bin/evsieve \
      --input "''${dev}" persist=reopen \
      --map btn:forward btn:forward@out \
      --map btn:back btn:back@out \
      --output @out name="BT5.1 extra pointer buttons"
  '';
in
{
  imports = [
    ../../modules/home/common.nix
    ../../modules/home/desktop.nix
    ../../modules/home/hyprland
    ../../modules/home/kwallet.nix # PAM unlock via systemd (before Hyprland apps)
    ../../modules/home/kde-apps.nix # without Plasma DE; skip if using modules/nixos/plasma.nix
    ../../modules/home/gaming.nix
    ../../modules/home/creative.nix
    ../../modules/home/spicetify.nix
    ../../modules/home/dev-tui.nix
    ../../modules/home/dev-gui.nix
    ../../modules/home/osx-kvm # macOS guest on NixOS via KVM — not nix-darwin
  ];

  programs.osx-kvm = {
    enable = true;
    resolution = "1920x1080";
  };

  home.packages = [
    pkgs.evsieve
    bt51-pointer-bridge
  ];

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
