---
name: nix
description: >-
  Edit, explain, and troubleshoot Nix flakes, NixOS, nix-darwin, Home Manager,
  overlays, and derivations. Use for .nix files, flake.lock updates, Nix builds,
  nh, and system or home configuration changes.
---

# Nix

Use the available file and shell tools; no particular agent, editor, MCP server,
or plugin is required. Commands need Nix with `nix-command` and `flakes` enabled;
fetching uncached inputs or substitutes needs network access, and builds need
access to the Nix store/daemon. Do not change the machine's Nix settings merely
to load this skill.

Read the repository's [AGENTS.md](../../../AGENTS.md) first and the relevant
topic under [docs/agents/](../../../docs/agents/). Those files own host policy,
secrets, channels, and deployment commands. Paths in commands are relative to
the flake root; documentation links are relative to this skill directory.
Read [commands.md](commands.md) for command examples and troubleshooting.

## Choose the target and scope

- Inspect the working tree and current branch before editing. Preserve existing
  changes. This repo starts work on `main`; do not discard work to change branches.
- Read `flake.nix`, its locked inputs, and the module or package that owns the
  behavior. Extend an existing module when possible.
- Identify the affected output and platform. `nixosConfigurations` is NixOS,
  `darwinConfigurations` is nix-darwin, and `homeConfigurations` is standalone
  Home Manager. A `packages` output builds a package; `devShells` supplies a
  development environment. Do not assume every flake exposes all of them.
- Here, NixOS and Darwin hosts integrate Home Manager into the system rebuild.
  `homeConfigurations."potter@roundabout"` is a scaffold, not roundabout's normal
  deployment path. Read [lib/hosts.nix](../../../lib/hosts.nix) before adding hosts.
- Keep existing x86_64 Linux hosts on `nixos-unstable-small`. ARM Linux uses the
  separate `nixpkgs-aarch64` input on `nixos-unstable`, requested for custard.
  Host constructors choose Darwin inputs separately; do not apply the Linux-only
  overlay to Darwin or make every input follow `nixpkgs`. Preserve the documented
  exceptions.

## Nix semantics that affect edits

A derivation describes a build. Nix normally computes its store paths from the
build description and dependencies; a fixed-output derivation instead declares
an expected content hash. A store path is not proof that a build succeeded or
that its result is reproducible. Ordinary `nix build` realizes outputs without
activating a system. Profiles retain generations; activation and rollback are
separate operations that may run scripts and restart services.

Flakes evaluate purely by default: ambient environment variables and arbitrary
host paths are restricted. Locked inputs may still be fetched during evaluation
or a build. `flake.lock` records input revisions and content hashes; purity does
not mean offline operation. Avoid `--impure` or `<nixpkgs>` as a general fix.

For local Git flakes, new untracked files are normally absent from the source
snapshot; edits to tracked files are included without a commit. Check this when
an imported file appears missing. Do not stage unrelated work or commit just to
evaluate. An explicit `path:.` can include untracked content too; inspect what
it would copy before using it, especially for secrets and large directories.

A path such as `./config.kdl` can be copied into the store when used by a
derivation. A string such as `"/home/potter/data"` is only text unless something
reads or coerces it; absolute runtime paths are valid when intentional.
`builtins.readFile` reads during evaluation. Keep plaintext secrets out of Nix
expressions, generated files, and derivations: store contents are generally
readable by other users. Use this repo's agenix workflow.

## Modules

- Use the module's supplied `pkgs`, `lib`, and `config`. Importing nixpkgs again
  can lose overlays, configuration, and the intended platform.
- `imports` selects modules; do not compute it from `config`, which can cause
  infinite recursion. Use `lib.mkIf` for conditional option definitions.
- Definitions merge by option type and priority, not by which file appears last.
  Lists usually concatenate; attribute sets merge according to their option
  types. Conflicting scalar definitions usually fail.
- Lower numeric override priorities win: ordinary definitions are 100,
  `lib.mkDefault` is 1000, and `lib.mkForce` is 50. `mkForce` can still conflict
  with another definition of equal priority. Fix ownership before forcing.
  `mkBefore` and `mkAfter` affect list ordering, not override priority.
- Use the existing shorthand module form, or explicit `options` and `config`
  when declaring options; do not mix top-level option definitions with explicit
  `config`. Check options against the pinned module implementation, since NixOS,
  nix-darwin, and Home Manager have different option namespaces.
- Leave existing `system.stateVersion` and `home.stateVersion` unchanged. They
  control compatibility defaults, not the package release. nix-darwin's
  `system.stateVersion` uses its own integer scheme.

## Packages and overlays

Use `final` for dependencies from the completed overlay set and `prev` for the
package being overridden. Referring to `final.foo` while defining `foo` can
recurse. `callPackage` fills named arguments from the package set; its explicit
argument set supplies overrides. `...` permits additional function arguments,
but is not a substitute for checking argument names.

```nix
final: prev: {
  foo = final.callPackage ./pkgs/foo { };
  bar = prev.bar.overrideAttrs (old: {
    postPatch = (old.postPatch or "") + ''
      # Append the needed patch here.
    '';
  });
}
```

Use `.override` for package function arguments and `.overrideAttrs` for
derivation attributes. Preserve existing hooks when appending. A package in an
overlay is not automatically exported as `packages.<system>.<name>`; inspect
the outputs before recommending `nix build '.#name'`.

For this repo's package updates, read [packages.md](../../../docs/agents/packages.md)
and use `update-local-packages --list` to discover supported targets and their
policies. Update selected targets for a scoped request. This command changes
package pins/hashes; `nix flake update` changes input locks. Neither substitutes
for the other. Use `pkgs.writeShellApplication` with `runtimeInputs` for installed
shell tools that need dependencies on `PATH`.

## Validate and finish

1. Use the installed `nix --version` and subcommand help when flags differ.
   Consult the pinned sources or official manuals for renamed options and APIs.
2. Parse changed Nix files, then evaluate the affected output with
   `--no-update-lock-file` during validation. It fails if lock resolution is
   required rather than silently updating dependencies. A syntax check alone
   does not validate imports, module options, or build behavior.
3. Build the affected package or system when appropriate. Prefer `--no-link`
   for validation so existing `result` links remain untouched. Broad
   `nix flake check` builds declared checks by default; `--no-build` only
   evaluates recognized outputs and does not comprehensively test custom Home
   Manager or Darwin outputs. Evaluate those explicitly. Build Darwin on a Mac
   or a configured Darwin builder; Linux evaluation is not a Darwin build test.
4. Change input locks only for the requested dependency work. Use
   `nix flake update <input>` for a scoped update; no arguments updates all
   inputs. Keep related `flake.nix` and `flake.lock` edits together and review
   the diff. Do not hand-invent lock or source hashes.
5. Apply only when machine changes are within the user's request. The installed
   `nh` wrapper runs `sync-age-recipients` before `os switch`, `os boot`,
   `os test`, and `darwin switch`; it may re-encrypt, commit, and push secrets.
   Even `nh os test` is an activation with that hook, not a validation command.
   See [secrets-and-ssh.md](../../../docs/agents/secrets-and-ssh.md).
6. Report what changed and which checks passed. Distinguish evaluation, builds,
   and activation, and state any missing daemon, network, or platform access.
   Do not commit, push, re-encrypt, install remotely, or collect garbage as an
   incidental part of editing this flake.

## References

- [Nix CLI manual](https://nix.dev/manual/nix/stable/command-ref/new-cli/nix)
- [NixOS module definitions](https://nixos.org/manual/nixos/stable/#sec-option-definitions)
- [Nixpkgs manual](https://nixos.org/manual/nixpkgs/stable/)
- [Home Manager manual](https://nix-community.github.io/home-manager/)
- [nix-darwin options](https://nix-darwin.github.io/nix-darwin/manual/)
