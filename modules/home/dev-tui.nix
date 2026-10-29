{ lib, pkgs, ... }:

{
  # Gate every T3 start, including the lingering user manager's boot-time start.
  # The user manager cannot order against the system's tailscaled.service.
  xdg.configFile."systemd/user/t3code.service.d/tailscale.conf".text = ''
    [Service]
    TimeoutStartSec=infinity
    ExecStartPre=${pkgs.tailscale}/bin/tailscale wait --timeout=0
    ExecStartPre=${pkgs.tailscale}/bin/tailscale ip --assert=''${T3CODE_HOST}
  '';

  programs.java = {
    enable = true;
    package = lib.mkDefault pkgs.jdk21;
  };

  home.packages = with pkgs; [
    cursor-cli
    t3code
    gh
    nodejs
    bun
    pnpm
    nil
    nixd
    quickemu
    ffmpeg-full
    imagemagickBig
    kitty
    bind
    doggo
    ldns
    cloudflare-speed-cli
    mullvad-compass
    codex
    mysql84
    discordchatexporter-cli 
  ];
}
