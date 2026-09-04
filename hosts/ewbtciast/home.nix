{
  imports = [ ../../modules/home/zsh.nix ];

  home.username = "potter";
  home.homeDirectory = "/Users/potter";
  home.stateVersion = "25.11";

  home.sessionVariables.EDITOR = "nano";
  programs.home-manager.enable = true;

  home.packages = [ ];
}
