{ config, pkgs, ... }:

{
  services.tailscale = {
    enable = true;
    useRoutingFeatures = "both";
    # UDP 41641: helps peers connect directly when not only via DERP
    openFirewall = true;
  };

  # Allow inbound on any port from the tailnet (NixOS firewall otherwise drops it).
  networking.firewall.trustedInterfaces = [ config.services.tailscale.interfaceName ];

  # Mullvad VPN (requires systemd-resolved)
  services.resolved.enable = true;
  services.mullvad-vpn = {
    enable = true;
    package = pkgs.mullvad-vpn; # GUI app (default is CLI-only mullvad)
  };
}
