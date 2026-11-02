{ pkgs, ... }:

{
  # Curated aarch64 Linux desktop apps. The host also selects common, niri,
  # kitty, kde-apps, and dev-tui, just as it does with the x86 desktop profile.
  imports = [ ../flameshot ];

  home.packages = with pkgs; [
    chromium
    vesktop
    mpv
    # JDownloader is not packaged in this nixpkgs pin.
    galculator
    gparted
    kdePackages.partitionmanager
    xed-editor
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
    libsForQt5.qt5ct
    qt6Packages.qt6ct
    adw-gtk3
    kdePackages.breeze
    kdePackages.breeze-gtk
    kdePackages.breeze-icons

    # Shelved EndeavourOS alternatives; use roundabout's app defaults.
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
    # kdePackages.breeze.qt5
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
