{ pkgs, ... }:

{
  # Roundabout's daily apps and appearance, with a smaller native ARM selection.
  # Keep extra VM GUIs, benchmarks, and duplicate Discord clients off the 4 GB Pi.
  imports = [ ../flameshot ];

  home.packages = with pkgs; [
    (google-chrome.override {
      commandLineArgs = "--password-store=kwallet6";
    })
    equibop
    bluebubbles
    mpv
    qbittorrent
    singularcard
    libimobiledevice
    usbmuxd
    # JDownloader is not packaged in this nixpkgs pin.
    galculator
    gparted
    kdePackages.partitionmanager
    flameshot
    grim
    playerctl
    duf
    tree
    tldr
    whois
    iperf3
    mesa-demos
    inxi
    wlr-randr
    xev
    wev
    # Match desktop.nix; DMS/qtengine own the live GTK/Qt themes via niri.
    nwg-look
    lxappearance
    libsForQt5.qt5ct
    qt6Packages.qt6ct
    adw-gtk3
    gtk3
    gtk4
    kdePackages.breeze
    kdePackages.breeze.qt5
    kdePackages.breeze-gtk
    kdePackages.breeze-icons

    # Shelved EndeavourOS alternatives; use roundabout's app defaults.
    # chromium # Google Chrome has a native ARM package in this pin.
    # vesktop # Use Equibop, matching roundabout.
    # xed-editor # Cursor comes from arm/dev-gui.nix.
    # grsync # Use the system-provided rsync CLI.
    # thunar # Dolphin comes from kde-apps.nix.
    # thunar-archive-plugin # Dolphin uses Ark.
    # thunar-volman # Dolphin handles volumes through UDisks/KIO.
    # xfce4-terminal # Kitty comes from dev-tui.nix.
    # xarchiver # Ark comes from kde-apps.nix.
    # wezterm # Use Kitty with the shared config.
    # pavucontrol # Use DMS audio controls.
    # networkmanagerapplet # Use DMS network controls.
    # glances # btop comes from common.nix.
    # iperf # Enable iperf2 only for older peers.

    # Already supplied by system modules.
    # rsync
    # sshfs
    # wget
  ];

  home.pointerCursor = {
    enable = true;
    name = "Posy_Cursor_Black";
    package = pkgs.posy-cursors;
    size = 24;
    gtk.enable = true;
    x11.enable = true;
  };

  xdg.mimeApps = {
    enable = true;
    defaultApplications."inode/directory" = [ "org.kde.dolphin.desktop" ];
  };
}
