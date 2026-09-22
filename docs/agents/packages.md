# Packages and overlays

`overlays.default` in `flake.nix` is `x86_64-linux` only. Darwin hosts do not use it. See [darwin.md](darwin.md).

## Local packages (`pkgs/*/default.nix`)

Each is `callPackage`'d in the overlay.

| Attr | What it is |
| --- | --- |
| `rofi-themes-collection` | Nailington's rofi theme fork (`inputs.rofi-themes`, `flake = false`) |
| `posys-cursor-scalable` | Posy's hyprcursor theme |
| `seguiemj`, `hojas-de-plata`, `google-sans`, `google-sans-flex` | fonts, also listed in `modules/nixos/common.nix` |
| `althea`, `singularcard` | Potter's apps |
| `cider` | Cider music client (packaged; the extracted AppImage under the workspace parent is leftover) |
| `twitch-drops-miner` | AppImage wrapper; copies itself to a writable dir because the app writes next to its binary |
| `auto-rob` | Electron app from Nailington/auto-rob releases, FHS env. Also what abacab's cron runs from `/mnt/storage/auto-rob` (that checkout is data, not this package) |
| `kde-craft` | FHS sandbox. See [kde-craft.md](kde-craft.md) |

`nix-index` in the overlay is `inputs.nix-index.packages.x86_64-linux.default`, not nixpkgs' copy.

## Temporary upstream fixes

These live in `overlays.default` and should be deleted once nixpkgs has them. Each has a comment with the reason:

- `helium` — from `inputs.helium` (`github:Nytelife26/nixpkgs/helium/init`) until the nixpkgs PR lands. Uses `legacyPackages`, so it cannot move onto Darwin as written.
- `openldap` — `doCheck` off on i686 only (koffydrop / nixpkgs#426717) so x86_64 still uses the cached build.
- `azahar` — add `#include <cstring>` after glibc 2.42 (azahar-emu/azahar#2232).
- `aseprite` — `fmt/core.h` → `fmt/format.h` when the quoted include is still present (fmt 12). The substitute is conditional so a later nixpkgs bump does not fail the build.

When a rebuild fails in one of these packages, check whether nixpkgs already fixed it before adding another patch.

## Caches

`modules/nixos/common.nix` trusts:

- `https://attic.xuyh0120.win/lantian` (Lantian, used by the CachyOS kernel path)
- `https://hyprland.cachix.org`

`niri-flake.cache.enable` is false on purpose.

## nix-ld

`programs.nix-ld.enable` is in `modules/nixos/common.nix`, so abacab gets it too. That is the intended place for "this host runs unpacked binaries," not a one-off package.

## Hardware packages that look like they should be one module

They are split because they are different projects:

- `modules/nixos/linuwu-sense/` — Linuwu-Sense kernel module (`package.nix` + module).
- `modules/nixos/damx/` — DAMX daemon and GUI.
- `modules/nixos/acer-sense/` — `acer-ctl.sh` for the DAMX plugin. It does not belong inside linuwu.

roundabout enables all three. Another host should import only the ones that match its hardware.
