{ config, pkgs, inputs, ... }:

{
  home.username = "potter";
  home.homeDirectory = "/home/potter";
  home.stateVersion = "25.11";

  # User packages
  home.packages = with pkgs; [
    # Discord with mods
    (discord.override {
      withOpenASAR = true;
      withVencord = true;
    })

    # Terminal & System
    fastfetch
    btop
    lshw
    kitty

    # Browsers & Apps
    google-chrome
    code-cursor

    # Fonts
    nerd-fonts.roboto-mono

    # Hyprland ecosystem
    waybar          # Status bar (used in hyprland.conf)
    rofi            # App launcher (native Wayland support)
    flameshot       # Screenshot tool (SUPER_SHIFT+X)
    brightnessctl   # Brightness control (laptop keys)
    playerctl       # Media player control (media keys)

    # Rofi themes collection (provides launcher_t5, powermenu_t1, etc.)
    rofi-themes-collection
  ];

  # Environment variables
  home.sessionVariables = {
    EDITOR = "nano";
  };

  # Let Home Manager install and manage itself
  programs.home-manager.enable = true;

  # Zsh with Oh My Zsh
  programs.zsh = {
    enable = true;
    oh-my-zsh = {
      enable = true;
      plugins = [ "git" ];
      theme = "essembeh";
    };
    # Add rofi scripts to PATH
    initExtra = ''
      # Rofi themes scripts are already in PATH via the package
    '';
  };

  # SSH Configuration
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
    };
  };

  # Hyprland window manager
  # Using extraConfig to load the .conf file, keeping config separate and editable
  wayland.windowManager.hyprland = {
    enable = true;
    package = null;       # Use the NixOS system package
    portalPackage = null;
    extraConfig = builtins.readFile ./hyprland.conf;
  };

  # Kitty terminal configuration
  programs.kitty = {
    enable = true;
    settings = {
      font_family = "RobotoMono Nerd Font";
      font_size = 12;
      background_opacity = "0.95";
      confirm_os_window_close = 0;
    };
  };

  # Waybar configuration (basic setup, customize as needed)
  programs.waybar = {
    enable = true;
    # Uses default config, you can customize with `settings` and `style` options
  };

  # Rofi configuration
  programs.rofi = {
    enable = true;
    package = pkgs.rofi;
    # The adi1090x themes handle their own config, so we keep this minimal
  };

  # Symlink rofi themes config to ~/.config/rofi
  # This allows the launcher scripts to find their themes
  xdg.configFile."rofi" = {
    source = "${pkgs.rofi-themes-collection}/share/rofi";
    recursive = true;
  };
}
