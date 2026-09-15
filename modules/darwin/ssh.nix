{
  config,
  lib,
  ...
}:

let
  loginKeys = import ../../lib/ssh-login-keys.nix;
  homeDir = config.users.users.potter.home;
  hostUserAge = ../../secrets/ssh/${config.networking.hostName}/id_ed25519.age;
  haveUserSecret = builtins.pathExists hostUserAge;
in
{
  # Incoming: nix-darwin already owns AuthorizedKeysCommand (cats
  # /etc/ssh/nix_authorized_keys.d/%u). Do not replace it with a GitHub curl —
  # that would drop flake keys. Live GitHub fetch stays NixOS-only; Darwin uses
  # the same snapshot as secrets/github-login-keys.nix (refresh via
  # sync-age-recipients, then rebuild).
  #
  # Outgoing identity: agenix → ~/.ssh/id_ed25519 when secrets/ssh/<host>/ exists.
  # First switch can omit that file. Then:
  #   1. Copy /etc/ssh/ssh_host_ed25519_key.pub into secrets/ssh/<host>/
  #   2. Run sync-age-recipients on roundabout (host pub becomes an age recipient)
  #   3. Generate the user key, agenix-encrypt it, rebuild — decrypt uses the host key

  services.openssh.enable = true;
  services.openssh.extraConfig = ''
    PasswordAuthentication no
    KbdInteractiveAuthentication no
  '';

  users.users.potter.openssh.authorizedKeys.keys = loginKeys;

  age.identityPaths = [
    "/etc/ssh/ssh_host_ed25519_key"
    "/etc/ssh/ssh_host_rsa_key"
    "${homeDir}/.ssh/id_ed25519"
  ];

  age.secrets = lib.mkIf haveUserSecret {
    user-ssh-key = {
      file = hostUserAge;
      owner = "potter";
      group = "staff";
      mode = "0600";
      path = "${homeDir}/.ssh/id_ed25519";
    };
  };
}
