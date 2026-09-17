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
  # Outgoing identity: agenix → ~/.ssh/id_ed25519 when secrets/ssh/<host>/id_ed25519.age exists.
  # nh darwin switch snapshots this machine's pubs into secrets/ssh/<host>/ (host + user).
  # Add the user pub to GitHub, then nh os switch on roundabout to re-encrypt secrets.

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
