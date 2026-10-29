# Minimal headless home for abacab — CLI tools only.
{
  imports = [
    ../../modules/home/common.nix
    ../../modules/home/dev-tui.nix
  ];

  # Bind the background T3 server to abacab's Tailscale address.
  xdg.configFile."systemd/user/t3code.service.d/host.conf".text = ''
    [Service]
    Environment="T3CODE_HOME=%h/.t3"
    Environment="T3CODE_HOST=100.120.61.10"
    Environment="T3CODE_PORT=3773"
  '';
}
