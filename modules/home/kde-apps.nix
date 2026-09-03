{ pkgs, ... }:

{
  # Optional KDE/Qt apps *without* the Plasma desktop (e.g. Hyprland / niri hosts).
  # Do NOT use this when enabling modules/nixos/plasma.nix — Plasma 6 already
  # provides Dolphin, Ark, KWallet stack, etc. via the desktop environment.

  home.packages = with pkgs; [
    kdePackages.dolphin
    # Standalone Dolphin needs these; Plasma pulls them in automatically
    kdePackages.kio
    kdePackages.kio-fuse
    kdePackages.kio-extras
    kdePackages.kio-admin # elevated ops (sudo/admin://) — not required for drive listing
    kdePackages.qtsvg # SVG icons in Dolphin
    kdePackages.ark
    kdePackages.kwallet
    kdePackages.kwalletmanager

    # KDE games
    kdePackages.kmines
    kdePackages.kpat
    kdePackages.ksudoku
    kdePackages.knetwalk
    kdePackages.kapman
    kdePackages.kblocks
    kdePackages.kbounce
    kdePackages.kollision
    kdePackages.kolf
  ];
}