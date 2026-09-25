{ pkgs, inputs, ... }:

{
  imports = [
    inputs.codex-desktop-linux.nixosModules.default
  ];

  # Compositor-agnostic desktop base. Import one session stack:
  #   niri.nix     → greetd + dms-greeter
  #   hyprland.nix → SDDM
  #   plasma.nix   → SDDM
  # Do not import niri.nix together with hyprland.nix or plasma.nix.

  services.xserver.enable = true;

  services.xserver.xkb = {
    layout = "us";
    variant = "";
  };

  programs.firefox.enable = true;

  # Community repackage of OpenAI's official Linux desktop. Optional
  # linuxFeatures stay off. nix-ld (common.nix) gets the workspace libs.
  programs.codexDesktopLinux = {
    enable = true;
    # linuxFeatures = [ "ui-tweaks" "remote-mobile-control" "remote-control-ui" ];
  };
  # Their flake nixConfig does not apply to an input; trust the cache here.
  nix.settings = {
    extra-substituters = [ "https://codex-desktop-linux.cachix.org" ];
    extra-trusted-public-keys = [
      "codex-desktop-linux.cachix.org-1:nX/xy6AdK9hQE24A8ALGjkCKj2ObFmcnemiL5Cid4nk="
    ];
  };

  services.printing.enable = true;

  services.pulseaudio.enable = false;
  security.rtkit.enable = true;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
  };

  hardware.bluetooth.enable = true;
  hardware.bluetooth.powerOnBoot = true;
  services.blueman.enable = true;
  hardware.bluetooth.settings = {
    General = {
      Privacy = "device";
      JustWorksRepairing = "always";
      FastConnectable = true;
    };
  };

  # Removable/internal volumes for file managers (Dolphin Solid backend, etc.)
  services.udisks2.enable = true;

  security.pam.services = {
    login.kwallet = {
      enable = true;
      package = pkgs.kdePackages.kwallet-pam;
    };
    greetd.kwallet = {
      enable = true;
      package = pkgs.kdePackages.kwallet-pam;
    };
    sddm.kwallet = {
      enable = true;
      package = pkgs.kdePackages.kwallet-pam;
    };
  };

  environment.sessionVariables = {
    NIXOS_OZONE_WL = "1";
    FUSERMOUNT_PROG = "${pkgs.fuse3}/bin/fusermount3";
    # Platform theme is qtengine (modules/nixos/niri.nix). Do not set
    # QT_QPA_PLATFORMTHEME here; a session variable would override it.
  };
}
