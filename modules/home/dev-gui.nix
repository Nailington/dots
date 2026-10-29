{ pkgs, ... }:

{
  home.packages = with pkgs; [
    sweetpad
    sim-relay
    github-desktop
    quickgui
    discordchatexporter-desktop
  ];

  # HM's regeneration hook deletes Cursor's mutable registry, which Cursor
  # repopulates with only the declared extensions. Keep the existing registry.
  home.file.".cursor/extensions/.extensions-immutable.json".enable = false;

  programs.cursor = {
    enable = true;
    mutableExtensionsDir = true;
    profiles.default = {
      extensions = [
        pkgs.sweetpad.vscodeExtension
        pkgs.vscode-extensions.vadimcn.vscode-lldb
      ];
      # Merge this path into the existing settings; keep GUI edits writable.
      mutableUserSettings = true;
      userSettings."sweetpad.remote.cliPath" = "${pkgs.sweetpad}/bin/sweetpad";
    };
  };
}
