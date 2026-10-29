{ config, pkgs, self, ... }:

{
  imports = [ ./ssh-github.nix ];

  nixpkgs.config = {
    allowUnfree = true;
  };

  time.timeZone = "America/New_York";
  i18n.defaultLocale = "en_US.UTF-8";
  i18n.extraLocaleSettings = {
    LC_ADDRESS = "en_US.UTF-8";
    LC_IDENTIFICATION = "en_US.UTF-8";
    LC_MEASUREMENT = "en_US.UTF-8";
    LC_MONETARY = "en_US.UTF-8";
    LC_NAME = "en_US.UTF-8";
    LC_NUMERIC = "en_US.UTF-8";
    LC_PAPER = "en_US.UTF-8";
    LC_TELEPHONE = "en_US.UTF-8";
    LC_TIME = "en_US.UTF-8";
  };

  networking.networkmanager.enable = true;

  programs.zsh.enable = true;
  users.defaultUserShell = pkgs.zsh;

  # Keep T3's user service running at boot and after the last logout.
  users.users.potter.linger = true;
  # HM supplies only the host-specific drop-in. T3 owns the writable base unit
  # so `t3 service restart` can regenerate it after an application update.
  systemd.services.t3code-install = {
    description = "Install and restart Potter's T3 Code user service";
    wantedBy = [ "multi-user.target" ];
    wants = [ "network-online.target" ];
    requires = [ "home-manager-potter.service" "linger-users.service" ];
    after = [
      "home-manager-potter.service"
      "linger-users.service"
      "systemd-user-sessions.service"
      "network-online.target"
    ];
    restartTriggers = [ config.home-manager.users.potter.home.activationPackage ];
    # A first install downloads and extracts T3's standalone runtime.
    path = [ pkgs.systemd pkgs.gnutar pkgs.gzip ];
    environment = {
      HOME = config.users.users.potter.home;
      # Keep service installation on the existing server home, separate from desktop.
      T3CODE_HOME = "${config.users.users.potter.home}/.t3";
    };
    serviceConfig = {
      Type = "oneshot";
      User = "potter";
      RemainAfterExit = true;
      # Wait for the user manager on first boot; enabling linger starts it asynchronously.
      ExecStartPre = "+${pkgs.runtimeShell} -c '${pkgs.systemd}/bin/systemctl start user@$(${pkgs.coreutils}/bin/id -u potter).service'";
    };
    script = ''
      export XDG_RUNTIME_DIR="/run/user/$(id -u)"
      ${pkgs.t3code}/bin/t3 service install
      ${pkgs.t3code}/bin/t3 service restart
    '';
  };

  # Unpatched dynamic binaries (FHS) — ld.so from nix-ld. abacab + any host on common.
  programs.nix-ld.enable = true;

  # Flakes + binary caches (Hydra/Attic; apply before first kernel switch)
  nix.settings = {
    experimental-features = [ "nix-command" "flakes" ];
    # Finish independent builds even when another package fails.
    keep-going = true;
    extra-substituters = [
      # CachyOS/Lantian kernel cache.
      "https://cache.lantian.pub/lantian"
      "https://hyprland.cachix.org"
    ];
    extra-trusted-substituters = [ "https://hyprland.cachix.org" ];
    extra-trusted-public-keys = [
      "lantian:WVGO7vsRMSEN+h7Lp7kv6SAmrkEXgUGbbXm7jMDjBuQ="
      "hyprland.cachix.org-1:a7pgxzMz7+chwVL3/pzj6jIBMioiJM7ypFP8PwtkuGc="
    ];
  };

  # Minimal system CLI — most apps live in Home Manager
  environment.systemPackages = with pkgs; [
    vim
    git
    git-lfs
    wget
    curl
    age
    self.packages.${pkgs.system}.nh
    self.packages.${pkgs.system}.sync-age-recipients
    self.packages.${pkgs.system}.update-local-packages
    fuse3
    e2fsprogs
    usbutils
  ];

  fonts.packages = with pkgs; [
    nerd-fonts.roboto-mono
    google-fonts
    googlesans-code
    nerd-fonts.googlesanscode
    seguiemj
    hojas-de-plata
    google-sans
    google-sans-flex
  ];

}
