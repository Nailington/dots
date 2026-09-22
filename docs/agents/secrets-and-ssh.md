# Secrets and SSH

Goal: every flake host can SSH to every other flake host, and every host's key can decrypt the age store, without copying private keys around by hand and without an SSH CA.

Public keys live on GitHub (`Nailington` and `HammerPot`, `lib/github-users.nix`). Private keys live in agenix. There is no sops-nix, no SSH CA, and no break-glass key in the repo.

## What is public vs secret

| Path | Contents | Commit? |
| --- | --- | --- |
| `lib/github-users.nix` | GitHub usernames | yes |
| `lib/ssh-keys.nix` | known user **public** keys, login fallback | yes |
| `secrets/recipients.nix` | age recipients: GitHub pubs **plus** host pubs | yes, written by the sync script |
| `secrets/github-login-keys.nix` | GitHub pubs only, for sshd | yes, written by the sync script |
| `secrets/ssh/<host>/*.pub` | snapshot of that host's user and host public keys | yes |
| `secrets/ssh/<host>/*.age` | encrypted private keys | yes (ciphertext) |
| `secrets/github.age` | GitHub PAT (`write:public_key`, plus `repo` if HTTPS push is the fallback) | yes (ciphertext) |
| `~/.ssh/id_ed25519` on a machine | decrypted user key, installed by agenix | never |

Host public keys are age recipients so a server can decrypt during activation using `/etc/ssh/ssh_host_ed25519_key`. They are **not** login keys. `sync-age-recipients` keeps them out of `secrets/github-login-keys.nix`. Putting a host key in `authorized_keys` would not help, and the script is written to avoid it.

Anyone can download a `.pub` from GitHub. That does not let them decrypt `.age` files. age encrypts to the public key; only the matching private key decrypts. A new machine can decrypt old secrets only after its public key is added to the recipient set **and** someone who can already decrypt re-encrypts. That re-encrypt is what `sync-age-recipients` does, and it has to run on a machine that already has an identity (today: roundabout).

## Login

`modules/nixos/ssh-github.nix` (imported from `common.nix`):

- `AuthorizedKeysCommand` curls `https://github.com/<user>.keys` for each name in `potter.ssh.githubUsers` (default `lib/github-users.nix`). Failure is non-fatal so a DNS outage does not lock SSH out.
- Static fallback: `lib/ssh-login-keys.nix` (the pubs in `lib/ssh-keys.nix` plus `secrets/github-login-keys.nix`) on both `potter` and `root`.
- Passwords and keyboard-interactive are off.
- If `secrets/ssh/<hostname>/id_ed25519.age` exists, agenix installs it at `/home/potter/.ssh/id_ed25519`.
- `age.identityPaths` is the host key and the user key.

Darwin cannot use that curl command: nix-darwin already owns `AuthorizedKeysCommand`. `modules/darwin/ssh.nix` installs the same static snapshot, and live GitHub fetch stays NixOS-only. After a new GitHub key appears, `sync-age-recipients` updates the snapshot and a Darwin rebuild picks it up.

## sync-age-recipients

On `PATH`. Also runs automatically at the start of `nh os switch`, `nh os boot`, `nh os test`, and `nh darwin switch`.

From the flake root it:

1. If `hosts/<this-hostname>/` exists, snapshots `/etc/ssh/ssh_host_ed25519_key.pub` into `secrets/ssh/<host>/`. Generates `~/.ssh/id_ed25519` only when the store does not already have `id_ed25519.pub`. An existing snapshot is left alone (no second key, no duplicate GitHub upload).
2. Fetches `https://github.com/<user>.keys` for each user in `lib/github-users.nix`.
3. Rebuilds recipient and login-key nix files.
4. Re-encrypts every `secrets/**/*.age` with the installer's identity (`~/.ssh/id_ed25519`, else the host key).
5. Commits and pushes **only** when the diff is non-empty. Default message: `Sync age recipients`. Push uses SSH (`git@github.com:...`) even when `origin` is HTTPS.

If this machine cannot decrypt (a new Mac whose key is not a recipient yet), it still commits new `.pub` snapshots and tells you to add `secrets/ssh/<host>/id_ed25519.pub` to GitHub, then run `nh os switch` on roundabout to re-encrypt. Do not invent a second path for that.

`SYNC_AGE_HOST` overrides hostname detection (macOS uses `scutil --get LocalHostName`).

## nixos-remote-install

Wrapper around nixos-anywhere. Name stays `nixos-remote-install`; do not rename the upstream tool. Needs the installer's `~/.ssh/id_ed25519` and a decryptable `secrets/github.age`.

```sh
nixos-remote-install --flake .#<host> root@<iso-ip>
```

`NIXOS_REMOTE_INSTALL_SKIP_SECRETS=1` skips prep and execs nixos-anywhere.

For a host that does not already have both `.age` keys, the script:

1. Generates `potter@<host>` and `<host> host` ed25519 keypairs in a temp dir.
2. POSTs the user pub to `https://api.github.com/user/keys` with the PAT from `secrets/github.age`. HTTP 201 and 422 (already present) are success.
3. Writes the pubs and age-encrypted privates under `secrets/ssh/<host>/`, encrypted to the **installer's** pubkey first.
4. Runs `sync-age-recipients` so the new GitHub key and the new host pub join the recipient set and every `.age` file (including the ones just written) is re-encrypted.
5. Copies the new private keys into nixos-anywhere's `--extra-files` (`/home/potter/.ssh` and the host key) so the machine can decrypt on first boot, then runs nixos-anywhere.

Re-running against a host that already has both `.age` files decrypts and reuses them. It does not mint another GitHub key.

First-time PAT, if `secrets/github.age` is missing:

```sh
printf '%s' 'ghp_...' | age -e -R ~/.ssh/id_ed25519.pub -o secrets/github.age
```

## Adding a machine to the mesh

1. Host directory + `mkNixosHost` / `mkDarwinHost` (see [layout.md](layout.md)).
2. NixOS: install with `nixos-remote-install` from roundabout. Darwin: `nh darwin switch` on the Mac, which snapshots pubs; add the user pub to GitHub; `nh os switch` on roundabout to re-encrypt.
3. Add an SSH client `matchBlocks` entry in `modules/home/ssh.nix` if the alias should exist on every host.

After that, `potter` on any enrolled host logs in with `~/.ssh/id_ed25519`, and sshd accepts every key published on the GitHub accounts in `lib/github-users.nix`.
