# Flattened GitHub snapshot + known user pubs for sshd authorized_keys.
# Keep host keys out of this list (those belong in age recipients only).
let
  sshKeys = import ./ssh-keys.nix;
  githubLoginKeys =
    if builtins.pathExists ../secrets/github-login-keys.nix then
      import ../secrets/github-login-keys.nix
    else
      [ ];
  unique =
    list: builtins.foldl' (acc: x: if builtins.elem x acc then acc else acc ++ [ x ]) [ ] list;
in
unique (sshKeys.loginKeys ++ githubLoginKeys)
