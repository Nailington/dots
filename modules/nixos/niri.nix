{ pkgs, lib, inputs, ... }:

{
  # niri-flake’s NixOS module (disables nixpkgs programs.niri). Required so DMS
  # niri.includes can rename the generated config to hm.kdl. Session glue lives
  # in modules/home/niri — do not import hyprland.nix unless you want both sessions.
  imports = [ inputs.niri.nixosModules.niri ];

  programs.niri.enable = true;
  # niri-flake’s niri-stable lags nixpkgs; DMS wants current niri from nixpkgs.
  programs.niri.package = pkgs.niri;

  niri-flake.cache.enable = false;

  # niri-flake enables gnome-keyring; roundabout uses KWallet.
  services.gnome.gnome-keyring.enable = lib.mkForce false;

  # DMS has its own polkit agent.
  systemd.user.services.niri-flake-polkit.enable = false;

  security.polkit.enable = true;

  # X11 apps (Steam, some games). niri starts it from PATH when present.
  environment.systemPackages = [ pkgs.xwayland-satellite ];

  xdg.portal.extraPortals = [ pkgs.kdePackages.xdg-desktop-portal-kde ];
  xdg.portal.config.niri = {
    "org.freedesktop.impl.portal.FileChooser" = [ "kde" ];
    "org.freedesktop.impl.portal.Secret" = [ "kwallet" ];
  };
}
