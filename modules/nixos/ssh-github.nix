{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.potter.ssh;

  # Public list — same keys as GET /users/{user}/keys, no token needed at login.
  # https://docs.github.com/en/rest/users/keys
  loginKeys = import ../../lib/ssh-login-keys.nix;

  githubKeys = pkgs.writeShellScript "github-authorized-keys" ''
    set -u
    user="''${1:-}"
    case "$user" in
      potter|root) ;;
      *) exit 0 ;;
    esac
    # Best-effort: never fail closed if GitHub/DNS is unreachable (static keys still apply).
    for gh_user in ${lib.escapeShellArgs cfg.githubUsers}; do
      ${pkgs.curl}/bin/curl -fsSL --max-time 10 \
        -H "Accept: application/vnd.github+json" \
        -H "X-GitHub-Api-Version: 2026-03-10" \
        "https://github.com/''${gh_user}.keys" || true
    done
  '';

  hostUserAge = ../../secrets/ssh/${config.networking.hostName}/id_ed25519.age;
  haveHostSecret = builtins.pathExists hostUserAge;
in
{
  options.potter.ssh = {
    githubUsers = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = import ../../lib/github-users.nix;
      description = "GitHub accounts whose SSH pubkeys are authorized (github.com/<user>.keys).";
    };
  };

  config = {
    services.openssh.enable = true;
    services.openssh.hostKeys = lib.mkIf haveHostSecret [
      {
        path = "/etc/ssh/ssh_host_ed25519_key";
        type = "ed25519";
      }
    ];
    services.openssh.settings = {
      PasswordAuthentication = false;
      KbdInteractiveAuthentication = false;
      AuthorizedKeysCommand = "${githubKeys} %u";
      AuthorizedKeysCommandUser = "nobody";
    };

    # Static keys from the flake (GitHub snapshot + known user pubs). Live GitHub
    # fetch still runs at login for keys added since the last switch.
    users.users.potter.openssh.authorizedKeys.keys = loginKeys;
    users.users.root.openssh.authorizedKeys.keys = loginKeys;

    systemd.tmpfiles.rules = [
      "d /home/potter/.ssh 0700 potter users -"
      "z /home/potter/.ssh/id_ed25519 0600 potter users -"
      "z /home/potter/.ssh/id_ed25519.pub 0644 potter users -"
    ];

    # Decrypt with this machine's SSH key (user key on roundabout, host key on servers).
    age.identityPaths = [
      "/etc/ssh/ssh_host_ed25519_key"
      "/home/potter/.ssh/id_ed25519"
    ];

    age.secrets = lib.mkIf haveHostSecret {
      user-ssh-key = {
        file = hostUserAge;
        owner = "potter";
        group = "users";
        mode = "0600";
        path = "/home/potter/.ssh/id_ed25519";
      };
    };
  };
}
