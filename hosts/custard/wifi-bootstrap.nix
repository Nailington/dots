{ pkgs, ... }:

{
  # Place this private keyfile on the flashed card, outside the Nix build/store.
  # Import before NetworkManager starts so Wi-Fi connects without a login.
  systemd.services.custard-wifi-bootstrap = {
    description = "Import custard's first-boot Wi-Fi connection";
    wantedBy = [ "NetworkManager.service" ];
    before = [ "NetworkManager.service" ];
    unitConfig = {
      RequiresMountsFor = "/boot/firmware";
      ConditionPathExists = "/boot/firmware/custard-wifi.nmconnection";
    };
    serviceConfig.Type = "oneshot";
    path = [ pkgs.coreutils ];
    script = ''
      profiles=/etc/NetworkManager/system-connections
      install -d -m 0700 "$profiles"
      install -m 0600 -o root -g root /boot/firmware/custard-wifi.nmconnection \
        "$profiles/custard-wifi.nmconnection.tmp"
      mv -f "$profiles/custard-wifi.nmconnection.tmp" "$profiles/custard-wifi.nmconnection"
      sync -f "$profiles/custard-wifi.nmconnection"
      rm /boot/firmware/custard-wifi.nmconnection
    '';
  };
}
