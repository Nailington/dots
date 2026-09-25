{ pkgs, lib, config, inputs, ... }:

{
  # niri-flake’s NixOS module (disables nixpkgs programs.niri). Session glue
  # lives in modules/home/niri — do not import hyprland.nix or plasma.nix
  # (those use SDDM; this stack uses greetd + dms-greeter).
  imports = [
    inputs.niri.nixosModules.niri
    inputs.dank-greeter.nixosModules.default
    inputs.qtengine.nixosModules.default
  ];

  assertions = [
    {
      assertion = !config.programs.hyprland.enable;
      message = "modules/nixos/niri.nix (dms-greeter) conflicts with modules/nixos/hyprland.nix (SDDM). Import only one session stack.";
    }
    {
      assertion = !config.services.desktopManager.plasma6.enable;
      message = "modules/nixos/niri.nix (dms-greeter) conflicts with modules/nixos/plasma.nix (SDDM). Import only one session stack.";
    }
  ];

  programs.niri.enable = true;
  # niri-flake’s niri-stable lags nixpkgs; DMS wants current niri from nixpkgs.
  programs.niri.package = pkgs.niri;

  niri-flake.cache.enable = false;

  programs.dms-greeter = {
    enable = true;
    compositor.name = "niri";
    configHome = config.users.users.potter.home;
  };

  users.users.greeter.extraGroups = [
    "video"
    "render"
    "input"
  ];

  # niri-flake enables gnome-keyring; KDE apps use KWallet (prompt on demand).
  services.gnome.gnome-keyring.enable = lib.mkForce false;

  # DMS has its own polkit agent.
  systemd.user.services.niri-flake-polkit.enable = false;

  security.polkit.enable = true;

  # X11 apps (Steam, some games). niri starts it from PATH when present.
  environment.systemPackages = [
    pkgs.xwayland-satellite
    # Qt5 Breeze style. Qt6 Breeze is already in the home profile.
    pkgs.kdePackages.breeze.qt5
  ];

  # qt5ct and qt6ct stay installed (modules/home/desktop.nix). This session
  # uses qtengine so KDE apps follow DMS matugen colors with the Breeze style.
  # DMS rewrites ~/.config/qtengine/config.json on theme changes and keeps
  # theme.style; this file is the fallback at /etc/xdg/qtengine/config.json.
  programs.qtengine = {
    enable = true;
    config.theme = {
      colorScheme = "${config.users.users.potter.home}/.local/share/color-schemes/DankMatugen.colors";
      iconTheme = "breeze-dark";
      style = "breeze";
      font = {
        family = "Google Sans Flex";
        size = 12;
      };
      fontFixed = {
        family = "GoogleSansCode NF";
        size = 12;
      };
    };
  };

  xdg.portal.extraPortals = [ pkgs.kdePackages.xdg-desktop-portal-kde ];
  xdg.portal.config.niri = {
    "org.freedesktop.impl.portal.FileChooser" = [ "kde" ];
    "org.freedesktop.impl.portal.Secret" = [ "kwallet" ];
  };
}
