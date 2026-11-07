{ pkgs, ... }:

let
  qbittorrentInitialConfig = pkgs.writeText "qbittorrent-initial.conf" ''
    [LegalNotice]
    Accepted=true
    [BitTorrent]
    Session\DefaultSavePath=/mnt/storage/torrents
    Session\Interface=tailscale0
    Session\InterfaceName=tailscale0
    [Network]
    PortForwardingEnabled=false
    [Preferences]
    WebUI\Address=127.0.0.1
    WebUI\LocalHostAuth=false
  '';
in
{
  # The Web UI is loopback-only. Reach it from another machine with:
  # ssh -L 8080:127.0.0.1:8080 abacab
  services.qbittorrent = {
    enable = true;
    openFirewall = false;
    webuiPort = 8080;
  };

  # Prepare downloads only after the data disk mounts, so a missing disk
  # cannot silently fill the root filesystem.
  systemd.services.qbittorrent-storage = {
    description = "Prepare qBittorrent storage on abacab";
    requires = [ "mnt-storage.mount" ];
    after = [ "mnt-storage.mount" ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      ExecStart = "${pkgs.coreutils}/bin/install -d -m 2770 -o potter -g qbittorrent /mnt/storage/torrents";
    };
  };
  systemd.services.qbittorrent = {
    requires = [ "tailscaled.service" "qbittorrent-storage.service" ];
    after = [ "tailscaled.service" "qbittorrent-storage.service" ];
    # Seed once so Web UI password and torrent preferences survive restarts.
    preStart = ''
      configFile=/var/lib/qBittorrent/qBittorrent/config/qBittorrent.conf
      if [ ! -e "$configFile" ]; then
        ${pkgs.coreutils}/bin/install -Dm600 ${qbittorrentInitialConfig} "$configFile"
      fi
    '';
    serviceConfig = {
      # A second guard behind qBittorrent's own interface binding: peer
      # sockets cannot fall back to the VPS's public network interface.
      RestrictNetworkInterfaces = "lo tailscale0";
      UMask = "0007";
    };
  };
}
