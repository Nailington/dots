{ pkgs, inputs, ... }:

let
  # Plan C: submaps disable keyboard binds but bindm (Alt+drag) stays registered globally.
  plan-c-on = pkgs.writeShellScriptBin "plan-c-on" ''
    set -eu
    ${pkgs.hyprland}/bin/hyprctl --batch "\
      dispatch submap Plan C ; \
      keyword unbind ALT, mouse:272 ; \
      keyword unbind ALT, mouse:273"
  '';

  plan-c-off = pkgs.writeShellScriptBin "plan-c-off" ''
    set -eu
    ${pkgs.hyprland}/bin/hyprctl --batch "\
      dispatch submap reset ; \
      keyword bindm ALT, mouse:272, movewindow ; \
      keyword bindm ALT, mouse:273, resizewindow"
  '';

  polkitAgent = "${pkgs.kdePackages.polkit-kde-agent-1}/libexec/polkit-kde-authentication-agent-1";
in
{
  # Hyprland-only session. Later niri/DMS should use their own module — do not import this.
  # KWallet PAM unlock: modules/home/kwallet.nix (systemd graphical-session-pre), not exec-once.
  home.packages = with pkgs; [
    hyprpicker
    waybar
    rofi
    flameshot
    grim
    slurp
    brightnessctl
    playerctl
    networkmanagerapplet
    pavucontrol
    blueman
    hyprlock
    hypridle
    xev
    wev
    libnotify
    dunst
    wl-clipboard
    cliphist
    inputs.rofi-tools.packages.${pkgs.system}.default
    plan-c-on
    plan-c-off
    rofi-themes-collection
    kdePackages.polkit-kde-agent-1
  ];

  wayland.windowManager.hyprland = {
    enable = true;
    package = null; # Use the NixOS system package
    portalPackage = null;
    # Needed so graphical-session-pre (kwallet unlock) runs before session apps
    systemd.enable = true;
    extraConfig = ''
      # Polkit agent (Hyprland-specific). KWallet unlock is systemd — see modules/home/kwallet.nix
      exec-once = ${polkitAgent}

      ${builtins.readFile ./hyprland.conf}
    '';
  };

  programs.waybar.enable = true;

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

      "urgency=low" = {
        border-color = "#33ccff";
        default-timeout = 5000;
      };

      "urgency=critical" = {
        background-color = "#f23645";
        border-color = "#f23645";
        default-timeout = 0;
      };
    };
  };

  xdg.configFile."waybar/config".source = ./waybar/config;
  xdg.configFile."waybar/style.css".source = ./waybar/style.css;
  xdg.configFile."hypr/hyprlock.conf".source = ./hyprlock.conf;
  xdg.configFile."hypr/hypridle.conf".source = ./hypridle.conf;
  xdg.configFile."flameshot/flameshot.ini".source = ./flameshot.ini;

  programs.rofi = {
    enable = true;
    package = pkgs.rofi;
  };

  xdg.configFile."rofi" = {
    source = "${pkgs.rofi-themes-collection}/share/rofi";
    recursive = true;
  };
}
