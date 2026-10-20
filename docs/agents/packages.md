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
| `auto-rob` | Cattn/auto-rob releases: standalone headless CLI + Electron GUI in an FHS env. Installed on both NixOS hosts by `modules/home/common.nix`. Abacab's existing cron still runs the separate `/mnt/storage/auto-rob` checkout |
| `kde-craft` | FHS sandbox. See [kde-craft.md](kde-craft.md) |
| `sweetpad` | Nailington's remote Mac fork; matching Cursor extension at `sweetpad.vscodeExtension` |

`nix-index` in the overlay is `inputs.nix-index.packages.x86_64-linux.default`, not nixpkgs' copy.

## Updating local GitHub packages

`update-local-packages` is installed on NixOS by `modules/nixos/common.nix`.
It wraps [nix-update](https://github.com/Mic92/nix-update), editing the local
package definitions and recalculating source and dependency hashes. Run from
this checkout, or supply `--flake /path/to/newFlake` (`NH_FLAKE` also works):

```sh
update-local-packages --list
update-local-packages sweetpad althea    # selected packages
update-local-packages twitch-drops-miner # rehash the mutable dev-build ZIP
update-local-packages --all             # all supported packages
update-local-packages --build sweetpad  # also build CLI and extension
git diff
nh os switch -- --flake .#roundabout
```

For the first switch while the new script is still untracked, use
`nh os switch -- --flake path:.#roundabout` so Nix includes it.

The package installs Zsh completion for flags, package names (with their update
policies), and directories after `--flake`. Open a new terminal after switching.
Package suggestions come from `--list`, exclude packages already selected, and
are suppressed after `--all`. Completion only lists choices; it runs no updates.

Althea and SingularCard follow their default branches; SweetPad stays on
`codex/windows-remote-testing` and refreshes both Cargo and extension npm hashes.
T3 Code stays on published nightlies and refreshes its source and pnpm hashes.
Auto-rob follows stable releases from `Cattn/auto-rob`; the two Google Sans font
packages also follow stable GitHub releases.
Twitch Drops Miner always rehashes the current `dev-build` ZIP, even when its
tag/version is unchanged; it is also included in `--all`. The package exposes
the original download as `zip` for nix-update's `--custom-dep` handling. Hash
checks fetch that ZIP without extracting or building the application; `--build`
also verifies the full wrapper.
The supported targets and policies are in `scripts/update-local-packages.sh`;
expose new targets under `packages.x86_64-linux` before adding them there.

This command does not update `flake.lock`, commit, push, or apply the system.
Use `nix flake update` separately for inputs such as rofi-themes. It restores a
package's file to its pre-run contents if that update fails (including existing
uncommitted edits), continues with the other packages, and exits nonzero if any
failed. Without `--build`, fetching dependency hashes does not prove the app
builds; upstream changes can still need packaging fixes.

Output is verbose by default: each package prints its position in the run,
expected downloads, commands, live hash-fetching logs, elapsed time, and its
file changes. The packaged nix-update has a small local patch to stream stderr
while retaining it for hash parsing; Python output is unbuffered. A hash mismatch
with a `got:` value is expected during hash discovery. The updater uses that
value to replace the old hash; the final package status reports success/failure.

Source-based packages download GitHub repository archives. SweetPad additionally
fetches Rust crates and npm packages from its lockfiles; T3 fetches pnpm packages.
Auto-rob downloads the published application ZIP, and the Google Sans packages
download font ZIPs. These go into the Nix store. Nix may also fetch or build
tools required by the fetchers; application builds require `--build`.

Release-only binaries cannot track source commits: Auto-rob needs a newly
published ZIP. The updater currently excludes Posy's multi-archive cursor
theme, DAMX's coupled packages, and Cider's non-GitHub download. Local font files
are also unchanged.

## Auto-rob on NixOS

`auto-rob` follows upstream's CLI-first launcher: no arguments run one portfolio
job; `auto-rob --gui` opens the desktop app (also used by the desktop entry).
The CLI uses Nix's Node 22 directly, without Electron, a display, or an FHS
sandbox. The GUI retains the FHS wrapper. Both are installed by the shared
Linux Home Manager profile on roundabout and abacab.

```sh
auto-rob --help
auto-rob --version
auto-rob --check             # checks setup without starting a portfolio job
auto-rob list codex --json
auto-rob --gui
```

The default workspace is `~/.config/auto-rob/workspace` (respecting
`XDG_CONFIG_HOME`); `AUTO_ROB_WORKSPACE` selects another directory. Headless
runs require an existing strategy prompt and an authenticated Cursor or Codex
CLI with Robinhood connected. The package does not create or migrate account
state. Abacab's existing cron jobs still use `npm start` in
`/mnt/storage/auto-rob`; installing this package does not replace those jobs.

Use `update-local-packages auto-rob` to refresh the released ZIP and hash, or
`update-local-packages --build auto-rob` to also build the CLI and GUI wrappers.

## SweetPad on NixOS

`pkgs/sweetpad/default.nix` pins the CLI and editor extension to the same revision of
Nailington/sweetpad's `codex/windows-remote-testing` branch. The fork's `main`,
Homebrew formula, and Marketplace extension do not supply this remote workflow.
`modules/home/dev-gui.nix` installs the CLI and uses Home Manager's `programs.cursor`
to link the extension and its CodeLLDB dependency. Its registry-regeneration
marker is explicitly disabled: Home Manager's default hook deletes Cursor's
`extensions.json`, and Cursor then loses the existing installed-extension list.
Keep that hook disabled. Cursor's extensions remain mutable; existing settings
are merged with an absolute `sweetpad.remote.cliPath` and stay writable.
No Rust toolchain or manual Cargo install is needed on the laptop.

Apply the configuration, then install the fork VSIX through Cursor's normal
installer on the first setup or when upgrading the fork. This preserves the
existing extension registry and replaces a Marketplace SweetPad copy:

```sh
nh os switch -- --flake .#roundabout
nix build .#sweetpad-vscode -o /tmp/sweetpad-vscode
cursor --install-extension /tmp/sweetpad-vscode/share/vsix/sweetpad.vsix --force
```

Reload Cursor after switching. Disable auto-update for **SweetPad** in its
extension menu so a Marketplace update cannot replace the remote fork. Keep the
Mac unselected until its setup is ready. This setup does not target `ewbtciast`.

The CLI and extension are also exposed as `packages.x86_64-linux.sweetpad` and
`sweetpad-vscode`. The latter includes `share/vsix/sweetpad.vsix` for a manual
install in another editor.

When the other Mac is ready, install the same fork revision there, enable Remote
Login, configure Xcode/signing, and check that a noninteractive SSH session can
find its CLI. Then, from the laptop:

```sh
sweetpad remote add "iMac" <ssh-alias-or-user@host>
sweetpad doctor --remote "iMac"
sweetpad devices --remote "iMac"
```

Choose **SweetPad: Select Remote Mac** in the project's Cursor window. Simulator
streaming additionally needs an Apple Silicon Mac with Node/npm. SSH config,
private keys, the remote registry, and Mac provisioning are not managed by this
package.

## T3 Code nightly

On both NixOS hosts, `t3code-install.service` runs as potter after Home Manager
and the lingering user manager are ready: `t3 service install`, then
`t3 service restart`. It runs at boot and again when the home generation or T3
package changes. The first install needs network access to download T3's
standalone runtime. The base user unit stays writable and owned by T3.
Each host's `home.nix` supplies `~/.config/systemd/user/t3code.service.d/host.conf`,
binding port 3773 to that host's Tailscale IPv4 address. Update that drop-in if
the machine is re-enrolled with a different Tailscale address.

The `t3code` overlay in `flake.nix` builds the published nightly
`0.0.46-nightly.20261015.3158`, commit
`e6bbfdb9ffe8334bed1c9b992f828f04d30db7ea`, using nixpkgs' source package.
Home Manager's existing `t3code` entry installs it. Build it separately with
`nix build .#t3code`.

To update, run `update-local-packages t3code` (or `--build t3code`). This updates
the version, source revision/hash and `pnpmDeps` hash in the overlay. The resource
monitor follows the same source; if its Cargo dependencies change, its dependency
hash needs an override too. `nix flake update` alone does not advance this explicit
nightly pin.

Both launchers retain the C++ runtime in `LD_LIBRARY_PATH` because Linux
`node-pty` prebuilds lack a runtime search path. Remove that wrapper once
nixpkgs#569702 reaches the pinned input; keep the nightly source override.

## Temporary upstream fixes

These live in `overlays.default` and should be deleted once nixpkgs has them. Each has a comment with the reason:

- `helium` — from `inputs.helium` (`github:Nytelife26/nixpkgs/helium/init`) until the nixpkgs PR lands. Uses `legacyPackages`, so it cannot move onto Darwin as written.
- `khal` — pass `sphinxBuilders` as `"html man"`: the current Sphinx hook reads only the first element of a structured Bash array, otherwise skipping manual-page generation and failing with a missing `man` output. Remove when the hook handles arrays correctly.
- `openldap` — `doCheck` off on i686 only (koffydrop / nixpkgs#426717) so x86_64 still uses the cached build.
- `azahar` — add `#include <cstring>` after glibc 2.42 (azahar-emu/azahar#2232).
- `aseprite` — `fmt/core.h` → `fmt/format.h` when the quoted include is still present (fmt 12). The substitute is conditional so a later nixpkgs bump does not fail the build.
- `vmware-workstation` — wrap the GUI in system-library mode with current C GTK/font libraries, retaining VMware's bundled C++ GTK interfaces because their ABI differs from current gtkmm. Its GTK 3.14 cannot render DMS's modern adw-gtk3 theme, and its GLib/fontconfig cannot load current dconf/font configuration. Supply matching GTK schemas, the SVG-capable pixbuf loader cache, MIME data, and fallback icons; otherwise opening the file picker can abort with "No GSettings schemas are installed". Keep the GUI on X11 so the DMS XSettings bridge supplies live settings; do not force a theme name. Restore `unpacked/vmware-tools-windows/windows.iso` in the underlying package's `lib/vmware/isoimages` too: nixpkgs currently omits that component, and VMware's install menu resolves it through the underlying package's `libdir`. Services and VMX still use the upstream binaries.

When a rebuild fails in one of these packages, check whether nixpkgs already fixed it before adding another patch.

## Caches

`modules/nixos/common.nix` trusts:

- `https://attic.xuyh0120.win/lantian` (Lantian, used by the CachyOS kernel path;
  temporarily commented out while Attic is down)
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
