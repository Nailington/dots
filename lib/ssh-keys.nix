# SSH pubs used as age recipients and as a last-resort authorized_keys fallback.
# Rebuild login keys: secrets/github-login-keys.nix (written by sync-age-recipients).
{
  roundaboutPub = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAICcPW4GgprCFvEDs8PjPvjKKHTgQxyM8P2QnjyHewvrQ potter@roundabout";
  abacabUserPub = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIFIhx8tb7686CoxuGiKi9D+cQHc6qmOF8tby9QxaAxbd potter@abacab";

  # Static fallback when AuthorizedKeysCommand cannot reach GitHub (e.g. DNS on fresh VPS).
  loginKeys = [
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAICcPW4GgprCFvEDs8PjPvjKKHTgQxyM8P2QnjyHewvrQ potter@roundabout"
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIFIhx8tb7686CoxuGiKi9D+cQHc6qmOF8tby9QxaAxbd potter@abacab"
  ];
}
