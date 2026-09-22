# Darwin (ewbtciast)

2017 Intel iMac on OpenCore Legacy Patcher. Hostname `ewbtciast`. The user wants the Mac managed by this flake: nix-darwin is the system entry, Determinate is the Nix install, nix-homebrew owns Homebrew, Home Manager owns zsh.

## Why the pins look like this

Intel Macs are unsupported on nixos-unstable / nixpkgs 26.11. `mkDarwinHost` sends `x86_64-*` to `inputs.nixpkgs-darwin` (`nixpkgs-26.05-darwin`) and `allowDeprecatedx86_64Darwin`. Any other Darwin system uses `inputs.nixpkgs-unstable`. Linux never uses those inputs.

Matching 26.05 inputs (do not point them at nixos-unstable):

- `inputs.darwin` — `github:nix-darwin/nix-darwin/nix-darwin-26.05`
- `inputs.home-manager-darwin` — `github:nix-community/home-manager/release-26.05`
- `inputs.nixpkgs-darwin`

`inputs.nixpkgs` stays `nixos-unstable` for roundabout and abacab. Their `follows` lines for the Darwin inputs are commented out in `flake.nix` so a Linux bump cannot drag the iMac forward.

26.05 EOLs at the end of 2026. Revisit the pin then; do not move the iMac early.

## Determinate and nix-darwin

Nix on the Mac was installed with the [Determinate Nix installer](https://github.com/DeterminateSystems/nix-installer), not with nix-darwin's Nix. `mkDarwinHost` imports `inputs.determinate.darwinModules.default` and sets `determinateNix.enable = true`.

Determinate owns `/etc/nix/nix.conf`. nix-darwin must not rewrite it. Settings that would have gone in `nix.settings` go in `determinateNix.customSettings` (see `hosts/ewbtciast/default.nix`: `max-jobs`, `lazy-trees`, `eval-cores`).

Do not import the Determinate module on a NixOS host.

`overlays.default` is not applied. It calls Linux-only packages and indexes `legacyPackages.x86_64-linux`. A Darwin-only package goes in `modules/darwin` or a Darwin `extraOverlays` entry, not in the Linux overlay.

## What the Mac imports

System: `modules/darwin/common.nix` (zsh, nix-homebrew, age, git, `nh`, `sync-age-recipients`, `btop`, `gh`, `cursor-cli`, `code-cursor`).

Home: `modules/home/zsh.nix` (Oh My Zsh, theme `essembeh`, git plugin) and `modules/home/ssh.nix`. Nothing from `modules/nixos/` and nothing from `modules/home/common.nix` (that file pulls a Linux package set).

`home.homeDirectory` is `/Users/potter`. Do not import `home/potter` here; that module hardcodes `/home/potter`.

Homebrew:

- Taps `homebrew-core` and `homebrew-cask` come from flake inputs (`flake = false`), `mutableTaps = false`, `autoMigrate = true`.
- `enableRosetta` is false. Rosetta's prefix is Apple Silicon only.
- `onActivation.cleanup = "uninstall"` and auto-update/upgrade are off, so a switch removes casks that left the list and does not upgrade the world.
- Add a cask with `homebrew.casks = [ "bluebubbles" ];` in `modules/darwin/common.nix` (or a host override). The list is the flake's list; `brew install --cask` on the machine will be undone on the next switch if it is not in the list.

## SSH enrollment

Same age store as Linux. Differences are in `modules/darwin/ssh.nix` and [secrets-and-ssh.md](secrets-and-ssh.md):

- Incoming keys are the committed GitHub snapshot, not a live curl.
- `nh darwin switch` snapshots this Mac's pubs into `secrets/ssh/ewbtciast/`.
- The user pub still has to be added to GitHub once. The hook does not POST to the GitHub API (that POST is `nixos-remote-install`, which is a NixOS installer path).
- Re-encrypt so the new key can open `secrets/*.age` by running `nh os switch` on roundabout.
- If `secrets/ssh/ewbtciast/id_ed25519.age` exists, agenix installs it to `/Users/potter/.ssh/id_ed25519` (group `staff`).

## Applying

On the iMac, from a checkout of this repo:

```sh
nh darwin switch -- --flake .#ewbtciast
```

The first switch is also nix-darwin's entry; Determinate is already the Nix daemon underneath. A full `nix build` of `darwinConfigurations.ewbtciast.system` from roundabout is the wrong loop.
