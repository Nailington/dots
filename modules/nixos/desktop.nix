{ pkgs, ... }:

{
  # Compositor-agnostic desktop base. Import hyprland.nix / plasma.nix / niri.nix
  # separately for the session you want.

  services.xserver.enable = true;
  services.displayManager.sddm.enable = true;
  services.displayManager.sddm.settings.General.Numlock = "on";

  services.xserver.xkb = {
    layout = "us";
    variant = "";
  };

  programs.firefox.enable = true;

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

  # KWallet PAM: SDDM stores creds in a socket; modules/home/kwallet.nix unlocks via systemd
  security.pam.services.sddm.kwallet.enable = true;
  security.pam.services.login.kwallet.enable = true;

  environment.sessionVariables = {
    NIXOS_OZONE_WL = "1";
    FUSERMOUNT_PROG = "${pkgs.fuse3}/bin/fusermount3";
  };
}
