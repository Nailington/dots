{ pkgs, ... }:

{
  home.packages = with pkgs; [
    (discord.override {
      withOpenASAR = true;
      withEquicord = true;
    })
    virt-manager
    discover-overlay
    equibop
    zoom-us
    slack
    # niri/Hyprland are not detected as KDE; without this Chrome falls back to basic store
    # when the wallet is locked at first launch and never prompts.
    (google-chrome.override {
      commandLineArgs = "--password-store=kwallet6";
    })
    bluebubbles
    cider
    auto-rob
    mpv
    qbittorrent
    singularcard
    libimobiledevice
    usbmuxd
    geekbench
    furmark
    mprime
    mesa-demos
    inxi
    # Theme testing tools
    nwg-look
    lxappearance
    libsForQt5.qt5ct
    qt6Packages.qt6ct
    gtk3
    gtk4
    # Fonts
    nerd-fonts.roboto-mono
    google-fonts
    googlesans-code
    seguiemj
    hojas-de-plata
  ];

  programs.kitty = {
    enable = true;
    settings = {
      font_family = "RobotoMono Nerd Font";
      font_size = 12;
      background_opacity = "0.95";
      confirm_os_window_close = 0;
    };
  };

  home.pointerCursor = {
    name = "theme_Posys-Cursor-Scalable-Black";
    package = pkgs.posys-cursor-scalable;
    size = 24;
    gtk.enable = true;
    x11.enable = true;
    hyprcursor.enable = true;
  };

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

  dconf.settings."org/gnome/desktop/interface" = {
    color-scheme = "prefer-dark";
    monospace-font-name = "RobotoMono Nerd Font 12";
    font-name = "Roboto 12";
  };

  qt = {
    enable = true;
    platformTheme.name = "qtct";
  };

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
