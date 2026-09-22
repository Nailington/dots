---
name: nix
description: >-
  Explains the Nix store, flakes, the module system, and the commands to
  build, switch, search, and update them. Use when editing .nix files,
  flake.nix, flake.lock, NixOS, nix-darwin, or Home Manager, or when the
  user mentions nix, flakes, nixos-rebuild, nh, overlays, or derivations.
---

# Nix

General Nix. This repo's hosts, secrets, desktops, and which branch to start from live in `AGENTS.md` and `docs/agents/`. Those files win when they name a specific command or file.

## Model

Nix builds **derivations** into the **store** (`/nix/store/<hash>-<name>`). The hash covers the inputs, so the same recipe produces the same path. A build adds a store path. It does not change the running system.

A **profile** is a symlink to a store path plus older generations. Switching (NixOS, nix-darwin, Home Manager) builds a new generation and activates it. Rollback boots or activates the previous generation.

A **flake** is a directory with `flake.nix` and, once resolved, `flake.lock`. Evaluation is pure: network access and the ambient `<nixpkgs>` channel are unavailable. Fetching happens when the lock is created or updated, and the lock records the revision.

```nix
{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs"; # one nixpkgs, shared with the parent
    };
    someSrc = {
      url = "github:owner/repo";
      flake = false; # a source tree, not a flake
    };
  };

  outputs = { self, nixpkgs, ... }@inputs: {
    # packages.<system>.<name>
    # nixosConfigurations.<host>
    # darwinConfigurations.<host>
    # homeConfigurations."<user>@<host>"
    # devShells.<system>.<name>
    # overlays.default = final: prev: { };
  };
}
```

`self` is this flake. Other outputs refer to it (`self.overlays.default`, `self.packages`).

`follows` makes an input use another's copy of a dependency. Use it when two flakes must see the same nixpkgs (Home Manager following NixOS). Leave it off when an input has to track its own nixpkgs; this repo's exceptions are commented in `flake.nix`.

## What each output is

| Output | Activated by | Builds |
| --- | --- | --- |
| `nixosConfigurations.<host>` | `nh os switch` on that Linux machine | A NixOS system |
| `darwinConfigurations.<host>` | `nh darwin switch` on that Mac | A nix-darwin system |
| `homeConfigurations."<user>@<host>"` | `home-manager switch --flake` | A user home, no system config |
| `packages.<system>.<name>` | `nix build .#<name>` | One package |
| `devShells.<system>.<name>` | `nix develop .#<name>` | A shell with tools, not an install |

On NixOS hosts here, Home Manager is a NixOS module, so `nh os switch` applies system and home together. The standalone `homeConfigurations` output is the pattern for a machine that has Nix and not NixOS.

`nh` is not a Nix command. It is a separate package this flake installs ([nix-community/nh](https://github.com/nix-community/nh)) to make installs easier: shorter switch commands, generation cleanup, and other quality-of-life features on top of `nixos-rebuild` and `darwin-rebuild`. The `nh` on `PATH` here is a further wrapper (`pkgs/nh-wrapped.nix`). `os switch`, `os boot`, `os test`, and `darwin switch` run `sync-age-recipients` before the real `nh`.

`darwinConfigurations.ewbtciast` builds on the Mac. A Linux `nix build` of that output is the wrong loop.

## Module system

NixOS, nix-darwin, and Home Manager configs are modules: `{ config, pkgs, lib, ... }: { imports = [ ]; options = { }; config = { }; }`.

- `imports` pulls in other modules. Host files select profiles by importing them.
- `pkgs` is already the overlaid package set. Use it. A second `import nixpkgs { }` inside a module creates a different instance.
- Later definitions merge. Lists and attrsets merge. Two plain values for one option conflict.
- `lib.mkDefault` is a weak value an importing module can override. `lib.mkForce` always wins. Set the option in the host module that should own it before reaching for `lib.mkForce`.
- `lib.mkIf cond { }` drops the attrset when `cond` is false.

`system.stateVersion` (NixOS) and `home.stateVersion` (Home Manager) mark the config's original release so stateful migrations stay stable. Leave the value already in the file.

## Overlays and packages

```nix
overlays.default = final: prev: {
  foo = final.callPackage ./pkgs/foo { };
  bar = prev.bar.overrideAttrs (old: {
    postPatch = (old.postPatch or "") + ''
      # patch
    '';
  });
};
```

`prev` is nixpkgs before this overlay. `final` is nixpkgs after every overlay. Call `final.callPackage` so the new package sees overlaid dependencies. Override with `prev.pkg` so you patch the original.

`callPackage` supplies function arguments from the package set by name. Extra arguments go in the second attrset. `...` on the package function swallows unused names; without it, a typo is an eval error.

Only attributes listed under `packages.<system>` in `flake.nix` are `nix build .#name`. An overlay attr is `nix build .#nixosConfigurations.<host>.pkgs.<attr>`.

A relative **path** (`./script.sh`, `./pkgs/foo`) is copied into the store and must stay inside the flake. A string (`"/home/potter/foo"`) is not, and it breaks purity. `builtins.readFile` on a path inlines the file at eval time.

## Commands

Run from the flake root. The longer catalog is [commands.md](commands.md).

```sh
nix flake show
nix flake update nixpkgs          # one input; commit flake.lock with flake.nix
nix search nixpkgs ripgrep
nix build .#nh
nix build .#nixosConfigurations.roundabout.config.system.build.toplevel
nh os switch -- --flake .#roundabout
nh os test  -- --flake .#roundabout    # activate, leave the boot entry
nh darwin switch -- --flake .#ewbtciast
```

`nix build` and `nix flake show` do not change the booted system. `nh os switch` and `nh darwin switch` do. Build the closed system first when a change is risky. On this repo those `nh` subcommands also run `sync-age-recipients` before the real switch.

Search and install through the flake. `nix profile install` and `nix-env -i` sit outside the config and drift away on the next switch.

## Practices

- Edit `flake.nix`, then `nix flake update <input>` or `nix flake lock`. Commit the lockfile in the same change. Hand-editing `flake.lock` hashes will not resolve.
- Update one input when that is the task. `nix flake update` with no arguments moves every input.
- Add a program by putting it in the module that already owns that kind of package (`environment.systemPackages` or `home.packages`). See `docs/agents/layout.md` for which file.
- Shell scripts installed by Nix go through `pkgs.writeShellApplication` so `runtimeInputs` land on `PATH`.
- Anything secret stays out of a derivation. Store paths are readable by every user. Encrypted secrets in this repo are agenix files; see `docs/agents/secrets-and-ssh.md`.
- A failed build prints a store path. `nix log <path>` shows the builder output. Fix the derivation, then build again. Re-running the same failing build hits the same cached failure; a real edit changes the hash.
- `lib.mkForce` is for a host that must beat a shared module. If two modules disagree, drop one import.
- `--impure` and `<nixpkgs>` opt out of flakes. Keep them inside the existing scripts that already need them.
- Garbage collection (`nix-collect-garbage -d`, `nh clean`) deletes store paths no generation still references. It is a disk task, not part of editing the flake.
- After a bad switch, reboot and pick the previous generation, or run `nh os rollback`.

## Changing this flake

1. Read `AGENTS.md`, then the one topic file that matches the edit.
2. Change the module or package. Leave `stateVersion` alone.
3. `nix flake show` or `nix build` the affected output.
4. Switch with `nh` only when the user wants the machine changed.
5. If `flake.nix` inputs changed, include `flake.lock`.
