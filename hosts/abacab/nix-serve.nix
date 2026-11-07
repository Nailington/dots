{ config, lib, pkgs, ... }:

{
  # Private binary cache — bind only to this host's Tailscale IPv4 address.
  age.secrets.abacab-cache.file = ../../secrets/abacab-cache.age;
  services.nix-serve = {
    enable = true;
    package = pkgs.nix-serve-ng;
    bindAddress = "100.120.61.10";
    port = 5000;
    openFirewall = false; # tailscale0 is already trusted; no public port.
    secretKeyFile = config.age.secrets.abacab-cache.path;
  };
  systemd.services.nix-serve = {
    requires = [ "tailscaled.service" ];
    after = [ "tailscaled.service" ];
    path = [ pkgs.tailscale ];
    preStart = ''
      tailscale wait
      tailscale ip --assert=100.120.61.10
    '';
    serviceConfig.TimeoutStartSec = "infinity";
  };

  # Custard's existing managed user key authenticates its Nix daemon.
  users.groups.nix-builder = { };
  users.users.nix-builder = {
    isSystemUser = true;
    group = "nix-builder";
    useDefaultShell = true;
    openssh.authorizedKeys.keys = [
      ("restrict " + lib.trim (builtins.readFile ../../secrets/ssh/custard/id_ed25519.pub))
    ];
  };
  nix.settings = {
    trusted-users = [ "nix-builder" ];
    # Leave capacity for the server's other services, including during ARM emulation.
    max-jobs = 2;
    cores = 3;
    # Sign remote-build outputs too, so custard can verify copied results.
    secret-key-files = [ config.age.secrets.abacab-cache.path ];
  };
}
