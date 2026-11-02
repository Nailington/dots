{ pkgs, ... }:

{
  # ARM GUI development tools, without the local x86-only SweetPad/sim-relay.
  home.packages = with pkgs; [
    github-desktop
    discordchatexporter-desktop
    meld
  ];

  # Match roundabout's editor while leaving its x86-only remote tooling out.
  home.file.".cursor/extensions/.extensions-immutable.json".enable = false;
  programs.cursor = {
    enable = true;
    mutableExtensionsDir = true;
    profiles.default = {
      extensions = [ pkgs.vscode-extensions.vadimcn.vscode-lldb ];
      mutableUserSettings = true;
    };
  };
}
