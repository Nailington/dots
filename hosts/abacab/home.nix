# Minimal headless home for abacab — CLI tools only.
{ pkgs, ... }:

{
  imports = [
    ../../modules/home/common.nix
    ../../modules/home/dev-tui.nix
  ];

  # Newer Minecraft server versions require Java 25.
  programs.java.package = pkgs.jdk25;

  # Bind the background T3 server to abacab's Tailscale address.
  xdg.configFile."systemd/user/t3code.service.d/host.conf".text = ''
    [Service]
    Environment="T3CODE_HOME=%h/.t3"
    Environment="T3CODE_HOST=100.120.61.10"
    Environment="T3CODE_PORT=3773"
  '';
}
