# Nix commands

Run from the flake root (`newFlake/`). `.#name` means `packages.<current-system>.name`. `nix` commands below are stock Nix. `nh` is a separate package; see Switch.

## Inspect

```sh
nix flake show                 # outputs in this flake
nix flake metadata             # resolved inputs and their revisions
nix flake check                # eval the flake's checks
nix search nixpkgs ripgrep     # registry nixpkgs; the locked input may differ
nix eval --raw .#nixosConfigurations.roundabout.config.networking.hostName
```

`nix repl .` loads flake outputs. Useful probes inside the repl: `nixosConfigurations.roundabout.config.networking.hostName`, `:b packages.x86_64-linux.nh` to build one attr.

## Build and run

```sh
nix build .#nh
nix build .#nixosConfigurations.roundabout.pkgs.cider
nix build .#nixosConfigurations.roundabout.config.system.build.toplevel
nix build .#homeConfigurations."potter@roundabout".activationPackage
nix run nixpkgs#hello -- --version
nix develop .#craft            # devShell; this one is the Craft sandbox
nix log /nix/store/....drv     # builder log for a failed derivation
nix why-depends .#nh glibc     # why one output depends on another
```

`nix build` leaves a `result` symlink in the current directory. It is a GC root. Delete it when finished so it does not pin an old closure.

Building `darwinConfigurations.ewbtciast.system` is done on the iMac.

## Update inputs

```sh
nix flake update nixpkgs       # move one input to the latest commit its URL allows
nix flake update               # every input
nix flake lock                 # re-resolve inputs whose URL changed, keep others
```

Commit `flake.lock` with the `flake.nix` change. Read the lock diff before committing an unscoped `nix flake update`.

## Switch

`nh` is an installed package, not part of the Nix CLI. Upstream `nh` is a quality-of-life wrapper around `nixos-rebuild` and `darwin-rebuild`. This repo's `nh` on `PATH` wraps that again (`pkgs/nh-wrapped.nix`): `os switch`, `os boot`, `os test`, and `darwin switch` run `sync-age-recipients` first, then the real `nh`.

```sh
nh os switch -- --flake .#roundabout     # build, activate, make it the boot default
nh os test   -- --flake .#roundabout     # activate only
nh os boot   -- --flake .#roundabout     # boot entry only; activates on reboot
nh os switch -- --flake .#abacab
nh darwin switch -- --flake .#ewbtciast  # on the Mac
```

The `--` before `--flake` passes the flag through this repo's wrapper to upstream `nh`.

Equivalent upstream commands, when the wrapper is the thing being debugged:

```sh
sudo nixos-rebuild switch --flake .#roundabout
sudo nixos-rebuild test   --flake .#roundabout
darwin-rebuild switch --flake .#ewbtciast
home-manager switch --flake .#potter@roundabout
```

## Generations

```sh
nh os rollback                 # activate the previous NixOS generation
nixos-rebuild list-generations
```

The bootloader lists previous generations. A generation that is still on the boot menu is a GC root.

## Store

```sh
nix path-info -Sh /run/current-system    # closure size
nix store diff-closures /run/current-system ./result
nix-collect-garbage -d         # delete paths not kept by any generation or result link
nh clean                       # nh's wrapper around generation cleanup
```

Run garbage collection only when the user asks. It cannot restore a generation it deleted.
