# Layout

## Tree

```
flake.nix                 inputs, outputs, Linux overlay
flake.lock
lib/hosts.nix             mkNixosHost, mkDarwinHost, mkHomeConfiguration
lib/github-users.nix      GitHub logins whose .keys are trusted
lib/ssh-keys.nix          static user pubs (age + login fallback)
lib/ssh-login-keys.nix    static pubs ++ secrets/github-login-keys.nix
home/potter/default.nix   Linux HM identity (username, /home/potter, stateVersion)
hosts/<name>/             one directory per machine
modules/nixos/            NixOS profiles
modules/home/             Home Manager profiles (mostly Linux)
modules/darwin/           nix-darwin profiles
pkgs/                     callPackage'd by overlays.default (Linux)
scripts/                  inlined into PATH tools by the flake
secrets/                  age files, recipient lists, public key snapshots
```

`specialArgs` on NixOS and Darwin include `self` and `inputs`. Home Manager gets `inputs` via `extraSpecialArgs`.

## What goes where

| Change | Put it in |
| --- | --- |
| True on every NixOS host (timezone, nix-ld, zsh, fonts, the SSH module) | `modules/nixos/common.nix` |
| True on every Linux potter home (CLI tools, OMZ, SSH client) | `modules/home/common.nix` |
| A desktop session that a host opts into | `modules/nixos/<session>.nix` plus `modules/home/<session>/` |
| Apps that belong to a session but not the DE itself | their own home module (`kde-apps.nix`, `gaming.nix`, …) |
| One computer's hardware, hostname, users, firewall, which profiles it imports | `hosts/<name>/default.nix` |
| That computer's Home Manager imports | `hosts/<name>/home.nix` |
| Disk layout for nixos-anywhere | `hosts/<name>/disk.nix` |
| A package Nixpkgs lacks, or a binary that needs an FHS env | `pkgs/<name>/` and `overlays.default` |
| A Linux-only overlay fix (helium, azahar, aseprite, openldap) | `overlays.default` in `flake.nix` |
| macOS system packages, Homebrew, Determinate | `modules/darwin/` |

`modules/home/zsh.nix` and `modules/home/ssh.nix` are the exception: both Linux `common.nix` and the Darwin home import them. Keep them free of Linux-only packages.

## Host registration

`flake.nix` wires hosts. The helpers always add agenix, Home Manager (`useGlobalPkgs`, `useUserPackages`, `backupFileExtension = "backup"`), and the right nixpkgs.

NixOS also gets `overlays.default`. Darwin gets Determinate (`determinateNix.enable = true`) and `home-manager-darwin`, and does not get `overlays.default`.

Adding a NixOS host:

1. `hosts/<name>/{default.nix,hardware-configuration.nix,home.nix}`.
2. Import `modules/nixos/common.nix` plus the profiles that host needs. Headless servers also import `modules/nixos/tailscale.nix` and skip desktop/gaming.
3. Home imports `home/potter` from `flake.nix`'s `homeModules`, then `hosts/<name>/home.nix` adds profiles.
4. SSH enrollment is automatic once `modules/nixos/common.nix` is imported (it pulls in `ssh-github.nix`). Install with `nixos-remote-install`, not a hand-copied key. See [secrets-and-ssh.md](secrets-and-ssh.md).
5. Register `nixosConfigurations.<name> = mkNixosHost { ... }`.
6. A host that nixos-anywhere formats also gets `disk.nix` and `disko.nixosModules.disko` in `modules`.

Adding a Darwin host: [darwin.md](darwin.md). Adding an HM-only host: `homeConfigurations."potter@<name>" = mkHomeConfiguration { modules = [ ./home/potter ./hosts/<name>/home.nix ]; }`. There is already a scaffold output `homeConfigurations."potter@roundabout"`. roundabout itself is still applied as a NixOS module, not via that output.

## Home module map (Linux)

| Module | Role |
| --- | --- |
| `common.nix` | zsh, ssh client, small CLI set (btop, ncdu, nix-index, …) |
| `desktop.nix` | GUI apps shared by a desktop host: Chrome (`--password-store=kwallet6`), Discord, Cider, virt-manager, flameshot, qt6ct. Imports `flameshot/`. Theme blocks in this file are commented on purpose. |
| `niri/` | DankMaterialShell + `config.kdl` and `dms/*.kdl` shipped from the flake |
| `hyprland/` | Hyprland session files. Commented out on roundabout. |
| `kde-apps.nix` | Dolphin, Ark, KWallet, KDE games **without** Plasma |
| `kde-craft.nix` | Craft wrappers. See [kde-craft.md](kde-craft.md) |
| `gaming.nix` / `creative.nix` / `spicetify.nix` | opt-in app groups |
| `dev-tui.nix` | JDK 21, cursor-cli, gh, node, bun, nil/nixd, kitty, DNS tools |
| `dev-gui.nix` | Cursor, GitHub Desktop, quickgui. No wrapper symlinks. |
| `kitty/` | kitty config files from the flake, not `programs.kitty` settings |
| `osx-kvm/` | QEMU macOS guest. Data lives in `~/VMs/osx-kvm` |
| `zsh.nix` / `ssh.nix` | shared with Darwin |

## NixOS module map

| Module | Role |
| --- | --- |
| `common.nix` | locale `America/New_York`, NetworkManager, zsh, nix-ld, caches, age, `nh`, fonts, `ssh-github.nix` |
| `desktop.nix` | PipeWire, Bluetooth, udisks2, printing, Firefox, kwallet PAM on `login` / `greetd` / `sddm`. No greeter of its own. |
| `niri.nix` | niri from nixpkgs (not niri-flake's older `niri-stable`), greetd + dms-greeter, DMS polkit, gnome-keyring off |
| `hyprland.nix` | `programs.hyprland` + `sddm.nix` |
| `plasma.nix` | Plasma 6 + `sddm.nix`. Brings its own Dolphin/Ark/KWallet UI |
| `sddm.nix` | SDDM, numlock on. niri must not import this |
| `gaming.nix` | Steam and friends |
| `virtualisation.nix` | libvirt/docker surface used by osx-kvm and virt-manager |
| `tailscale.nix` | Tailscale |
| `mullvad.nix` | Mullvad daemon |
| `networking-tailscale.nix` | both of the above; roundabout imports this. New headless hosts should import `tailscale.nix` alone |
| `hardware/nvidia-prime.nix` | PRIME sync |
| `linuwu-sense/` | Acer Nitro fan/keyboard driver. Separate from DAMX and acer-ctl |
| `damx/` | DAMX daemon + GUI module |
| `acer-sense/` | `acer-ctl` helper for the DAMX plugin, not part of linuwu |
| `ssh-github.nix` | authorized keys + agenix identity. See [secrets-and-ssh.md](secrets-and-ssh.md) |

## Flake packages on PATH

Built for `x86_64-linux` and installed by modules, not by `nix profile`:

| Package | What it is |
| --- | --- |
| `nh` | upstream `nh`, but `os switch/boot/test` and `darwin switch` call `sync-age-recipients` first |
| `sync-age-recipients` | refresh age recipients from GitHub `.keys` |
| `nixos-remote-install` | keygen, GitHub upload, agenix, then real `nixos-anywhere` |
| `kde-craft` | `craft`, `craft-setup`, `craft-shell`, `craft-run` |
| `twitch-drops-miner`, `auto-rob` | also exposed as `packages` for a direct build |

`devShells.x86_64-linux.craft` is `pkgs.kde-craft.devShell` (`nix develop .#craft`).
