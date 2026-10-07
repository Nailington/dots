# Encryption rules: publicKeys says WHO can decrypt each file, not WHAT is inside.
# github.age holds a GitHub PAT; ssh/<host>/*.age hold encrypted private SSH keys.
# Recipients come from GitHub + host public keys and retain previously added keys.
# sync-age-recipients expands recipients and re-encrypts (also commits and pushes).
# Declaring a file here does not install it: modules use age.secrets for that.
# See docs/agents/secrets-and-ssh.md.
let
  inherit (import ./lib/ssh-keys.nix) roundaboutPub;

  recipients =
    if builtins.pathExists ./secrets/recipients.nix then
      import ./secrets/recipients.nix
    else
      [ roundaboutPub ];

  sshDir = ./secrets/ssh;
  hosts =
    if builtins.pathExists sshDir then
      let
        dir = builtins.readDir sshDir;
      in
      builtins.filter (n: dir.${n} == "directory") (builtins.attrNames dir)
    else
      [ ];

  mkHostSecrets = host: {
    "secrets/ssh/${host}/id_ed25519.age".publicKeys = recipients;
    "secrets/ssh/${host}/ssh_host_ed25519_key.age".publicKeys = recipients;
  };
in
builtins.foldl' (acc: host: acc // mkHostSecrets host) {
  "secrets/github.age".publicKeys = recipients;
} hosts
