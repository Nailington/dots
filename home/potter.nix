{ config, pkgs, lib, inputs, ... }:

{
  home.username = "potter";
  home.homeDirectory = "/home/potter";
  home.stateVersion = "25.11";

  # User packages
  home.packages = with pkgs; [
    # Discord with mods
    (discord.override {
      withOpenASAR = true;
#      withVencord = true;
      withEquicord = true;
    })



    # Terminal & System
    nix-du
    ncdu
    furmark  # GPU benchmark and stress test
    mprime
    unrar
    altserver-linux
    althea
    singularcard
    libimobiledevice  # idevicepair, ideviceinfo etc. for iOS device management
    usbmuxd           # USB multiplexer daemon for iOS devices
    fastfetch
    btop
    lshw
    kitty
    nmap
    mesa-demos

    # Browsers & Apps
    zoom-us
    slack
    google-chrome
    code-cursor
    github-desktop
    gh              # GitHub CLI
    nix-index       # Index of which packages provide which files (nix-locate)
    geekbench
    equibop

    krita
    inkscape
    blender

    # JavaScript/TypeScript development
    nodejs          # Node.js runtime
    bun             # Fast JavaScript runtime & bundler
    pnpm

    discover-overlay  # Discord voice/friends overlay for Linux
    (heroic.override {
      extraPkgs = pkgs': with pkgs'; [ gamemode ];
    })
    prismlauncher  # Minecraft launcher (PolyMC fork)
#    protontricks    # Run Winetricks commands for Proton/Steam games    || Disabled in favor of steam flag
    wineWow64Packages.stagingFull  # Wine with 32-bit and 64-bit support
    winetricks                # Wine configuration and dependency installer
    protonup-qt
    lutris                    # Game launcher for Linux
    gamescope
    mangohud
    r2modman                  # Thunderstore mod manager
    twitch-drops-miner  # Auto-farm Twitch drops (AppImage from dev-build)
    bluebubbles     # iMessage client
    cider           # Apple Music client
    mullvad-vpn     # Mullvad VPN GUI
    mpv             # Video player
    qbittorrent     # BitTorrent client
    mcpelauncher-client  # Minecraft Bedrock launcher
    mcpelauncher-ui-qt
    # OBS with NVENC support
    (wrapOBS {
      plugins = with obs-studio-plugins; [
        obs-vaapi           # Hardware encoding (VA-API)
        obs-vkcapture       # Vulkan/OpenGL game capture
        obs-pipewire-audio-capture  # PipeWire audio capture
      ];
    })

    # GPU Screen Recorder - lightweight replay buffer
    gpu-screen-recorder      # CLI tool
    gpu-screen-recorder-gtk  # GTK GUI

    # Fonts - Roboto family
#    roboto                   # Roboto sans-serif
    nerd-fonts.roboto-mono   # Roboto Mono (monospace)
#    roboto-slab              # Roboto Slab (serif)
#    roboto-serif             # Roboto Serif
    google-fonts
    googlesans-code
    seguiemj                 # Segoe UI Emoji
    hojas-de-plata           # Hojas De Plata (local TTF)


    # Hyprland ecosystem
    hyprpicker      # Color picker for Wayland/Hyprland
    waybar          # Status bar (used in hyprland.conf)
    rofi            # App launcher (native Wayland support)
    flameshot       # Screenshot tool (SUPER_SHIFT+X)
    brightnessctl   # Brightness control (laptop keys)
    playerctl       # Media player control (media keys)
    networkmanagerapplet  # nm-applet for network management
    pavucontrol     # PulseAudio/PipeWire volume control GUI
    blueman         # Bluetooth manager GUI
    hyprlock        # Hyprland screen locker
    hypridle        # Idle daemon for auto-lock
    xev
    libnotify       # Provides notify-send
    dunst           # Notification daemon (installed but not running)
    wl-clipboard
    cliphist
    inputs.rofi-tools.packages.${pkgs.system}.default
    

    # Rofi themes collection (provides launcher_t5, powermenu_t1, etc.)
    rofi-themes-collection

    # Theme testing tools
    nwg-look           # GTK theme switcher (Wayland-native)
    lxappearance       # GTK theme switcher (classic)
    libsForQt5.qt5ct   # Qt5 configuration tool
    qt6Packages.qt6ct  # Qt6 configuration tool
    gtk3               # Includes gtk3-demo
    gtk4               # Includes gtk4-demo
  ];

  # Environment variables
  home.sessionVariables = {
    EDITOR = "nano";
#    QT_QPA_PLATFORMTHEME = lib.mkForce "qt6ct";  # Use qt6ct for Qt theming
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
    initContent = ''
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

  # Waybar configuration (loaded from separate files)
  programs.waybar.enable = true;

  # Dunst notification daemon (disabled while testing mako)
  services.dunst = {
    enable = false;
    settings = {
      global = {
        width = 300;
        height = 300;
        offset = "30x50";
        origin = "top-right";
        transparency = 10;
        frame_color = "#33ccff";
        font = "RobotoMono Nerd Font 10";
        corner_radius = 10;
      };
      urgency_low = {
        background = "#1a1b26";
        foreground = "#ffffff";
        timeout = 5;
      };
      urgency_normal = {
        background = "#1a1b26";
        foreground = "#ffffff";
        timeout = 10;
      };
      urgency_critical = {
        background = "#f23645";
        foreground = "#ffffff";
        frame_color = "#f23645";
        timeout = 0;
      };
    };
  };

  # Mako notification daemon
  services.mako = {
    enable = true;
    settings = {
      font = "RobotoMono Nerd Font 10";
      background-color = "#1a1b26";
      text-color = "#ffffff";
      border-color = "#33ccff";
      border-radius = 10;
      border-size = 2;
      width = 300;
      height = 300;
      margin = "10";
      padding = "15";
      default-timeout = 5000;
      layer = "overlay";
      anchor = "top-right";
      max-icon-size = 32;
      #group-by = "none";

      "urgency=low" = {
        border-color = "#33ccff";
        default-timeout = 5000;
      };

      "urgency=critical" = {
        background-color = "#f23645";
        border-color = "#f23645";
        default-timeout = 0;
      };

#      "on-notify" = "exec makoctl menu -- rofi -theme $HOME/.config/rofi/launchers/type-5/style-4.rasi -dmenu ";
    };
  };

  # Symlink waybar config files to ~/.config/waybar
  xdg.configFile."waybar/config" = {
    source = ./waybar/config;
  };
  xdg.configFile."waybar/style.css" = {
    source = ./waybar/style.css;
  };
  
  # Hyprlock config
  xdg.configFile."hypr/hyprlock.conf" = {
    source = ./hyprlock.conf;
  };
  
  # Hypridle config
  xdg.configFile."hypr/hypridle.conf" = {
    source = ./hypridle.conf;
  };
  
  # Flameshot config
  xdg.configFile."flameshot/flameshot.ini" = {
    source = ./flameshot.ini;
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

  # Cursor theme - handles symlinking to ~/.local/share/icons/ automatically
  home.pointerCursor = {
    name = "theme_Posys-Cursor-Scalable-Black";
    package = pkgs.posys-cursor-scalable;
    size = 24;
    gtk.enable = true;
    x11.enable = true;
    hyprcursor.enable = true;
  };

  # GTK theming - Breeze Dark
  gtk = {
    enable = true;
    theme = {
      name = "Breeze-Dark";
      package = pkgs.kdePackages.breeze-gtk;
    };
    iconTheme = {
      name = "breeze-dark";
      package = pkgs.kdePackages.breeze-icons;
    };
    font = {
      name = "Roboto";
      size = 12;
    };
    gtk3.extraConfig = {
      gtk-application-prefer-dark-theme = true;
      gtk-font-name = "Roboto 12";
    };
    gtk4.extraConfig = {
      gtk-application-prefer-dark-theme = true;
      gtk-font-name = "Roboto 12";
    };
  };

  # Force GTK4/libadwaita apps to respect dark theme
  dconf.settings."org/gnome/desktop/interface" = {
    color-scheme = "prefer-dark";
    monospace-font-name = "RobotoMono Nerd Font 12";
    font-name = "Roboto 12";
  };


  # Qt theming - Breeze Dark via qt5ct/qt6ct
  qt = {
    enable = true;
    platformTheme.name = "qtct";
  };

  # qt5ct config
  xdg.configFile."qt5ct/qt5ct.conf".text = ''
    [Appearance]
    color_scheme_path=${pkgs.libsForQt5.qt5ct}/share/qt5ct/colors/darker.conf
    custom_palette=true
    icon_theme=breeze-dark
    standard_dialogs=default
    style=Breeze

    [Fonts]
    fixed="RobotoMono Nerd Font Propo [GOOG],12,-1,5,50,0,0,0,0,0,Regular"
    general="Roboto,12,-1,5,50,0,0,0,0,0,Regular"

    [Interface]
    stylesheets=
  '';

  # qt6ct config
  xdg.configFile."qt6ct/qt6ct.conf".text = ''
    [Appearance]
    color_scheme_path=${pkgs.qt6Packages.qt6ct}/share/qt6ct/colors/darker.conf
    custom_palette=true
    icon_theme=breeze-dark
    standard_dialogs=default
    style=Breeze

    [Fonts]
    fixed="RobotoMono Nerd Font Propo [GOOG],12,-1,5,50,0,0,0,0,0,Regular"
    general="Roboto,12,-1,5,50,0,0,0,0,0,Regular"

    [Interface]
    stylesheets=
  '';
}

