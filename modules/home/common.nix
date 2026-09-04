{ pkgs, ... }:

{
  imports = [ ./zsh.nix ];

  home.sessionVariables = {
    EDITOR = "nano";
  };

  programs.home-manager.enable = true;

  programs.ssh = {
    enable = true;
    matchBlocks = {
      "hammerpot" = {
        hostname = "hammerpot-server";
        identityFile = "~/.ssh/ssh-key-2024-11-04.key";
        user = "ubuntu";
      };
      "crack" = {
        identityFile = "~/.ssh/oracle.key";
        user = "ubuntu";
      };
      "abacab" = {
        hostname = "abacab";
        identityFile = "~/.ssh/id_ed25519";
        user = "potter";
      };
      "osx-kvm" = {
        hostname = "nixos";
        port = 10022;
        user = "potter";
      };
      "geoimac" = {
        hostname = "192.168.6.36";
        user = "gsiii";
      };
      "potterimac" = {
        hostname = "192.168.6.36";
        user = "potter";
      };
    };
  };

  home.packages = with pkgs; [
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
