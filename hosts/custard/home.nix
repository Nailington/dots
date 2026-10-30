{ pkgs, ... }:

{
  imports = [
    ../../modules/home/common.nix
    ../../modules/home/niri
    ../../modules/home/kitty
    ../../modules/home/kde-apps.nix
    ../../modules/home/dev-tui.nix
    ../../modules/home/flameshot
    # ../../modules/home/desktop.nix # Mixed x86-only apps; keep the Pi app set below.
    # ../../modules/home/dev-gui.nix # Includes x86-only local SweetPad/sim-relay packages.
    # ../../modules/home/gaming.nix # Includes x86-only games/Wine; Prism is selected below.
    # ../../modules/home/creative.nix # Includes CUDA OBS/Unity; Inkscape is selected below.
    # ../../modules/home/spicetify.nix # Spotify's Linux client is x86-only.
    # ../../modules/home/osx-kvm # Intel macOS guests need an x86 host.
  ];

  # Apps carried over from EndeavourOS that are not supplied by the imports.
  # ARM metadata/evaluation and exceptions are recorded in docs/custard/.
  home.packages = with pkgs; [
    chromium
    vesktop
    github-desktop
    mpv
    inkscape
    prismlauncher
    # JDownloader is not packaged in this nixpkgs pin; see the migration manifest.
    meld
    galculator
    grsync
    gparted
    kdePackages.partitionmanager
    thunar
    thunar-archive-plugin
    thunar-volman
    xfce4-terminal
    xarchiver
    xed-editor
    wezterm
    pavucontrol
    networkmanagerapplet
    flameshot
    grim
    playerctl
    rsync
    sshfs
    glances
    duf
    tree
    tldr
    wget
    whois
    iperf
    iperf3
    mesa-demos
    inxi
    libsForQt5.qt5ct
    qt6Packages.qt6ct
    adw-gtk3
    kdePackages.breeze
    kdePackages.breeze.qt5
    kdePackages.breeze-gtk
    kdePackages.breeze-icons
  ];

  home.pointerCursor = {
    enable = true;
    name = "Posy_Cursor_Black";
    package = pkgs.posy-cursors;
    size = 24;
    gtk.enable = true;
    x11.enable = true;
  };

  # No fixed Tailscale bind address has been assigned to this new host.
  # Keep T3's default loopback binding until enrollment; the shared guard is for
  # roundabout/abacab, whose host.conf supplies their explicit T3CODE_HOST.
  xdg.configFile."systemd/user/t3code.service.d/tailscale.conf".enable = false;
  xdg.configFile."systemd/user/t3code.service.d/host.conf".text = ''
    [Service]
    Environment="T3CODE_HOME=%h/.t3"
    Environment="T3CODE_HOST=127.0.0.1"
    Environment="T3CODE_PORT=3773"
  '';

  # Match roundabout's Dolphin directory handler without importing its app list.
  xdg.mimeApps = {
    enable = true;
    defaultApplications."inode/directory" = [ "org.kde.dolphin.desktop" ];
  };
}
