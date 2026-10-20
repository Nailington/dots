{ pkgs, ... }:

{
  imports = [
    ./zsh.nix
    ./ssh.nix
  ];

  home.sessionVariables = {
    EDITOR = "nano";
  };

  programs.home-manager.enable = true;

  home.packages = with pkgs; [
    auto-rob
    nix-du
    ncdu
    unrar
    fastfetch
    (btop.override {
      rocmSupport = true;
      cudaSupport = true;
    })
    lshw
    libinput
    nmap
    screen
    nix-index
    zip
    unzip
    sqlite
    tea
  ];
}
