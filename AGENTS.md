# AGENTS.md

Potter's multi-host Nix flake. Git repo: [Nailington/dots](https://github.com/Nailington/dots). The Cursor workspace parent `nixOSmoment/` is an unversioned pile of pre-flake files (`configuration.nix`, old `hyprland.conf`, font drops, `nginx-conf/`). Live config is this directory. Edit here.

Read this file first. Open one topic doc when the task needs it. Start from `main` unless the user says they are on another branch.

| Topic | File |
| --- | --- |
| Where code belongs, how to add a host | [docs/agents/layout.md](docs/agents/layout.md) |
| roundabout, abacab, ewbtciast | [docs/agents/hosts.md](docs/agents/hosts.md) |
| agenix, GitHub keys, remote install | [docs/agents/secrets-and-ssh.md](docs/agents/secrets-and-ssh.md) |
| niri / Hyprland / Plasma, KWallet | [docs/agents/desktops.md](docs/agents/desktops.md) |
| Intel iMac, Determinate, Homebrew | [docs/agents/darwin.md](docs/agents/darwin.md) |
| Overlays and local packages | [docs/agents/packages.md](docs/agents/packages.md) |
| KDE Craft sandbox | [docs/agents/kde-craft.md](docs/agents/kde-craft.md) |

## What this flake is for

One flake, many machines, same user (`potter`). A host opts into profiles by import. Shared behavior lives in `modules/`. Anything that is true of only one computer lives in `hosts/<name>/`.

Three host kinds, three constructors in `lib/hosts.nix`:

| Kind | Constructor | Output |
| --- | --- | --- |
| NixOS | `mkNixosHost` | `nixosConfigurations.<name>` |
| macOS | `mkDarwinHost` | `darwinConfigurations.<name>` |
| Nix on Ubuntu/Fedora, no NixOS | `mkHomeConfiguration` | `homeConfigurations."potter@<name>"` |

`osx-kvm` is a macOS *guest* on NixOS (QEMU). It is a Linux home module, not a Darwin host.

## Nixpkgs split

Linux always tracks `github:NixOS/nixpkgs/nixos-unstable` (`inputs.nixpkgs`).

Darwin is split because Intel Macs left unstable in 26.11:

- `x86_64-darwin` → `inputs.nixpkgs-darwin` (`nixpkgs-26.05-darwin`) and `nix-darwin` / home-manager `26.05`, until 26.05 EOLs at the end of 2026.
- other Darwin (future Apple Silicon) → `inputs.nixpkgs-unstable`.
- `mkDarwinHost` does this check. Keep new Darwin hosts on that helper.

`overlays.default` is Linux-only (hardcoded `x86_64-linux` packages). Darwin hosts pass `extraOverlays` only, which defaults to empty.

Inputs that must **not** follow `nixpkgs`:

- `spicetify-nix` — it tracks a Spotify version it can patch.
- `nix-cachyos-kernel` — CachyOS kernel ABI; applied only as `extraOverlays` on roundabout.
- `determinate` — Darwin only. Never import `determinate.nixosModules` on Linux.

## Where apps go

System profiles stay small: shell, nix, age, fonts, hardware, services. Day-to-day apps go in Home Manager.

- Linux identity: `home/potter` sets `home.username`, `/home/potter`, and `home.stateVersion = "25.11"`. Import it on every Linux potter home.
- Darwin does **not** import `home/potter`. The iMac home is `/Users/potter` and is set in `hosts/ewbtciast/home.nix`.
- `modules/home/common.nix`, `desktop.nix`, `niri`, `hyprland`, `dev-gui.nix`, `gaming.nix`, `creative.nix`, `kde-apps.nix`, `osx-kvm` are Linux. Darwin home imports `zsh.nix` and `ssh.nix` only.
- `modules/nixos/*` is NixOS only. A future HM-only host imports `modules/home/*` and nothing under `modules/nixos/`.

`stateVersion` stays at `"25.11"` on existing hosts. Do not bump it to match nixpkgs.

## How to work

- Prefer extending an existing module over a new file. Potter has rejected extra scripts and modules that were not asked for.
- When shelving config (themes, a compositor, a mount), comment the block out. Leave it in the file so it can come back.
- Host-specific imports are commented in the host file with a one-line reason (`# Hyprland + SDDM — enable later / other hosts`). Follow that pattern.
- `lib/hosts.nix` is the checklist for adding a host. Read it before inventing a fourth constructor.
- Commands the user runs are on `PATH` after a switch: `nh`, `sync-age-recipients`, `nixos-remote-install`. Do not tell them to `nix run` those scripts.
- `nh os switch` / `nh os boot` / `nh os test` / `nh darwin switch` run `sync-age-recipients` first (`pkgs/nh-wrapped.nix`). That hook may commit and push when recipients actually change, and it skips the commit when nothing changed. Do not make a separate git commit for the same secret refresh unless asked.
- Do not commit, push, or re-encrypt secrets unless the user asked, or you are fixing a bug in those scripts. Never print decrypted `secrets/*.age` contents. `secrets/github.age` is a GitHub PAT.
- Public keys in `lib/ssh-keys.nix` and `secrets/recipients.nix` are fine to read. Do not copy password hashes out of host files into chat or docs.

Apply from the flake root:

```sh
nh os switch -- --flake .#roundabout      # this laptop
nh os switch -- --flake .#abacab          # headless server
nh darwin switch -- --flake .#ewbtciast   # iMac; run on the Mac
nixos-remote-install --flake .#<host> root@<iso-ip>
```

Building `darwinConfigurations.ewbtciast` needs the iMac (or a Darwin builder). Linux can read the modules; it is not the install path.

## Branches

`main` is the default branch. Work starts there. Potter cuts a branch when a change might be destructive (a big refactor, a new host kind, a sandbox that should not land until it works). Finish or abandon that branch, then return to `main`. Do not treat a side branch as the current config unless the user says they are on it.

Examples of that pattern: `niri`, `macos`, `refactor`, `pre-flake`, and `craft`. What landed from those experiments is already on `main`. The branch itself is the scratch copy.

## Branches of intent that already lost

Recorded so they are not proposed again:

- SSH certificates / a hammerpot.dev CA. Replaced by GitHub `.keys` plus agenix.
- sops-nix. The secret store is agenix.
- A break-glass age identity sitting in the repo.
- Reusing the old `24fire` SSH key. Treat it as untrusted; abacab has its own keypair.
- Putting Plasma and niri on the same host. One greeter stack per host.
