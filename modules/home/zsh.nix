{ ... }:

{
  # Shared OMZ — imported by Linux common.nix and Darwin home. Do not put
  # Linux-only packages here.
  programs.zsh = {
    enable = true;
    oh-my-zsh = {
      enable = true;
      plugins = [ "git" ];
      theme = "essembeh";
    };
  };
}
