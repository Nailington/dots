# Nix commands

Run from the flake root. Quote whole installables so shells such as Zsh do not
expand special characters. For an attribute containing `@`, preserve the Nix
double quotes inside shell single quotes. Use an output that actually exists.

`nix` commands require the Nix CLI and store access. `nh`, `home-manager`, and
`darwin-rebuild` are separate programs. Check installed help for version-specific
flags; do not install another Nix or change daemon settings merely to run checks.

## Inspect and evaluate

```sh
nix --version
nix flake show --no-update-lock-file
nix flake metadata --no-update-lock-file
nix-instantiate --parse modules/home/common.nix > /dev/null
nix eval --no-update-lock-file --raw '.#nixosConfigurations.roundabout.config.networking.hostName'
nix eval --no-update-lock-file --raw '.#nixosConfigurations.roundabout.config.system.build.toplevel.drvPath'
nix eval --no-update-lock-file --raw '.#homeConfigurations."potter@roundabout".activationPackage.drvPath'
nix flake check --no-build --no-update-lock-file
```

Parsing checks syntax only. Evaluating a `drvPath` forces derivation evaluation
without realizing the output, though evaluation can fetch sources or trigger
import-from-derivation builds. `flake show` is an output inventory, not a full
configuration test. `flake check` without `--no-build` also builds its declared
checks. Custom `homeConfigurations` and `darwinConfigurations` need explicit
evaluation/builds; a passing generic check does not cover them automatically.

`--no-update-lock-file` rejects needed lock changes. `--no-write-lock-file`
instead allows in-memory resolution without saving it, so it is less strict
for validation against the checked-in lock. Neither flag means offline.

```sh
nix repl --no-update-lock-file .
```

Inside the REPL, inspect
`nixosConfigurations.roundabout.config.networking.hostName` or use
`:b packages.x86_64-linux.nh` to build. Use `:?` for available REPL commands.

## Search the pinned package set

```sh
nix eval --no-update-lock-file --raw '.#nixosConfigurations.roundabout.pkgs.ripgrep.version'
nix eval --no-update-lock-file --json '.#nixosConfigurations.roundabout.pkgs' --apply 'p: builtins.filter (n: builtins.match ".*ripgrep.*" n != null) (builtins.attrNames p)'
```

For a broader search, `nix search nixpkgs ripgrep` uses the registry's nixpkgs,
which may differ from this flake's lock and overlays. Confirm the attribute in
the target host's `pkgs` before editing. For module options, inspect the pinned
module declarations rather than assuming a web result matches this revision.

## Build

```sh
nix build --no-link --no-update-lock-file '.#nh'
nix build --no-link --no-update-lock-file '.#nixosConfigurations.roundabout.pkgs.cider'
nix build --no-link --no-update-lock-file '.#nixosConfigurations.roundabout.config.system.build.toplevel'
nix build --no-link --no-update-lock-file '.#homeConfigurations."potter@roundabout".activationPackage'
# On the iMac, or with a configured Darwin builder:
nix build --no-link --no-update-lock-file '.#darwinConfigurations.ewbtciast.system'
```

`--no-link` realizes the output without creating a `result` symlink. If a result
link is useful, choose an explicit `--out-link` path rather than overwriting an
existing one. `nix build` normally creates a GC-root link; a `--no-link` result
is not retained by such a link.

```sh
nix develop --no-update-lock-file '.#craft'
```

This enters the Craft development shell; it does not install or activate a
system. Read the Craft topic doc before using the sandbox.

## Update inputs or packages

Run mutation commands only for the requested update:

```sh
nix flake update nixpkgs          # selected input
nix flake update nixpkgs agenix   # selected inputs
nix flake update                 # all inputs
nix flake lock                   # resolve missing/changed inputs, preserve others
update-local-packages --list
update-local-packages sweetpad   # one supported local package
update-local-packages --build sweetpad
git diff -- flake.nix flake.lock pkgs
```

Preserve `nixos-unstable-small` and the separate Darwin input selection.
Do not add `follows` to every input. Inspect the lock diff for unexpected changes
to transitive dependencies. Include the resulting lock edits with input changes;
this is not permission to commit or push. Package updates can need new source
and dependency hashes even when `flake.lock` is unchanged.

## Activate and recover

These commands change a machine. Here, the four `nh` actions below also run
`sync-age-recipients`, which may re-encrypt, commit, and push. Use them when
applying configuration is requested, not as a build check.

```sh
nh os switch -- --flake '.#roundabout'     # activate and make boot default
nh os test   -- --flake '.#roundabout'     # activate without making boot default
nh os boot   -- --flake '.#roundabout'     # make boot default; activate at reboot
nh darwin switch -- --flake '.#ewbtciast'  # run on the Mac
```

These are this repo's documented invocation forms. The local wrapper forwards
its arguments unchanged to upstream `nh`; consult its source and installed help
when debugging argument handling. Naming `abacab` selects its configuration;
it does not itself send the activation to that server. Run on the intended host
or use an explicitly requested remote workflow from the repository docs.

Standalone Home Manager uses `home-manager switch --flake '.#user@host'` with
the real output name on the intended host. Do not use the roundabout scaffold
to replace its integrated Home Manager deployment.

```sh
nh os info                       # inspect NixOS generations
nh os rollback                   # activate a prior generation when recovery is requested
```

Previous boot generations can also be selected in the bootloader. A rollback
does not undo application data migrations or arbitrary activation side effects.
Generation deletion/GC (`nh clean`, `nix-collect-garbage -d`) removes recovery
options and belongs to an explicitly requested cleanup task.

## Diagnose failures

Read the first useful error and its owning package/module. Retry with
`--show-trace` for an evaluation error or `-L` on `nix build` for live build logs.

- **Missing file:** inspect `git status --short` and `git ls-files -- path`.
  Git flake snapshots omit untracked files. If using `path:.` to include them,
  first check for local credentials and large directories that would enter the
  store snapshot. Do not stage or commit as a hidden validation step.
- **Undefined option or attribute:** check spelling, imports, platform, and
  the pinned revision. Do not add `mkForce` to hide an ownership conflict.
- **Infinite recursion:** check imports depending on `config`, overlay references
  to the value being defined, and extra nixpkgs imports.
- **Hash mismatch:** confirm the intended source revision and fetcher. Source
  archive, unpacked source, Cargo, npm, and pnpm hashes are not interchangeable.
  Use the existing updater or the appropriate fetcher to obtain the real hash;
  a temporary `lib.fakeHash` during an intentional update must be replaced.
- **Build failure:** use `nix log` with the actual failing `.drv` path from the
  output. Fix the cause, then rebuild. Network/daemon failures can be transient;
  do not edit a derivation solely to change its hash or assume every failure is
  cached permanently.
- **Access or platform failure:** report missing network, daemon socket access,
  or a suitable builder. Do not disable the sandbox, signature checking, or
  platform checks as a routine fix.

For realized closures:

```sh
nix path-info -Sh /run/current-system
nix store diff-closures /run/current-system ./result
nix why-depends --no-update-lock-file '.#nh' '.#nixosConfigurations.roundabout.pkgs.glibc'
```

The closure diff assumes `./result` already points to the intended new build.
`why-depends` can realize its arguments; use it when that build is appropriate.
