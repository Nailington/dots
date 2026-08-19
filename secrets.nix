# agenix secrets. Recipients = GitHub .keys (+ host pubs) from secrets/recipients.nix,
# refreshed by sync-age-recipients (nixos-remote-install and nh os switch; commits + pushes).
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
