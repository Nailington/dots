{
  # Mullvad VPN (requires systemd-resolved). Desktop-oriented; skip on headless servers.
  services.resolved.enable = true;
  services.mullvad-vpn = {
    enable = true;
    # pkgs.mullvad-vpn is GUI-only now; daemon comes from the default service package
    gui.enable = true;
  };
}
