# KDE Craft

Craft is KDE's meta-build system. It clones sources, keeps a Python venv, and writes into a prefix. That prefix cannot live in the Nix store. This repo does not package KDE apps through Craft; it gives Craft an FHS sandbox so the prefix can build on NixOS.

Docs: https://community.kde.org/Craft

## Layout

| Piece | Role |
| --- | --- |
| `pkgs/kde-craft/default.nix` | `buildFHSEnv` + four wrappers. Overlay attr `kde-craft`. `passthru.devShell` is the `devShells.x86_64-linux.craft` output |
| `pkgs/kde-craft/entry.sh` | Runs **inside** the FHS. Verbs: `setup`, `shell`, `craft`, `run` |
| `pkgs/kde-craft/bootstrap.py` | First-time Craft install, called by `craft-setup` |
| `modules/home/kde-craft.nix` | Puts the wrappers on PATH and sets `CRAFT_ROOT` to `~/CraftRoot` |
| `~/CraftRoot` | Mutable prefix. Not in git, not managed by Home Manager |

The inner `support` derivation also installs `/usr/bin/craft` and friends so a nested `nix develop` does not wrap a second FHS around the one you are already in.

Do not add nixpkgs Qt or KDE Frameworks to `fhsTargetPkgs`. Craft builds or downloads those into CraftRoot. If both exist, CMake picks up the Nix prefix and the build goes wrong. System libraries Craft expects (glibc, X11, Wayland, pulse, cmake, a wrapped gcc) do belong in the FHS.

## Commands

```sh
craft-setup                  # first install into $CRAFT_ROOT
craft-shell                  # source craftenv.sh; prompt shows CraftRoot
nix develop .#craft          # same shell
craft <blueprint>            # e.g. craft kate, craft kolf
craft --run kolf            # run a merged binary inside the sandbox
craft-run <cmd>              # run any Craft-built binary in the sandbox
```

`CRAFT_ROOT` overrides the prefix. It has to stay outside the Nix store.

`entry.sh` rewrites `Paths/Python` in `etc/CraftSettings.ini` when it points at `/nix/store/...`. CraftBootstrap otherwise records `dirname(sys.executable)` from inside the sandbox, and that store path disappears after GC. The pinned value is `/usr/bin`.

If a Nix Python upgrade breaks the venv (`etc/virtualenv/3/bin/python3` exists but is not executable):

```sh
rm -rf "$CRAFT_ROOT/etc/virtualenv"
craft craft
```

## Toolchain notes encoded in the FHS

- Use the wrapped `gcc` / `binutils` (`stdenv.cc`, `gcc`, `binutils`). The unwrapped `gcc.cc` also ships `/usr/bin/gcc`; FHS `ignoreCollisions` then leaves the raw compiler on PATH and the link fails with missing `Scrt1.o` / `crti.o`.
- The FHS `profile` sets `NIX_CC_WRAPPER_TARGET_HOST_*` and `NIX_BINTOOLS_WRAPPER_TARGET_HOST_*` so the wrappers inject `-B<glibc>/lib`.
- Audio libs in the FHS: `alsa-lib`, `libpulseaudio`, `pipewire`, `libjack2`. A missing libpulse is why an earlier `craft kolf` configure failed. Add a discovered `-dev` dependency here, not via a nixpkgs Qt stack.
- CA bundle is exported as `SSL_CERT_FILE`, `NIX_SSL_CERT_FILE`, and `REQUESTS_CA_BUNDLE`.

## Notes from the `craft` branch

This sandbox was developed on branch `craft`, a side branch for work that should not land on `main` until it is ready. `main` is the default. Continue there unless the user is on `craft`.

On roundabout, `~/CraftRoot` exists. A `craft-shell` session built and qmerged `kde/kdegames/kolf` (26.08.1) and launched it with `craft --run kolf`. Fontconfig then printed warnings from `/etc/fonts/conf.d/48-guessfamily.conf` and `49-sansserif.conf` (`invalid constant` / `xsi:nil`). The binary still started.

Switching that blueprint's git source to a custom fork failed once after the stock build succeeded. The fork's blueprint (`craft/blueprints` or the package's `.py` source URL) is the first place to look. Stock `kolf` is a known-good compile.

Roundabout also installs `kdePackages.kolf` through `modules/home/kde-apps.nix`. That is the distro package. Craft's `kolf` is a separate prefix under `~/CraftRoot/bin`.

## When changing the sandbox

- Keep CraftRoot writable and out of the store.
- Rebuild the wrapper (`nh os switch`, or `nix build .#kde-craft`) before expecting `craft-shell` to see new libraries. An already-open shell is the old FHS.
- A new library belongs in `fhsTargetPkgs` with a one-line reason if it is there to satisfy a specific configure error.
- Platforms are `x86_64-linux` only.
