# Packaged with nix-update and its dependencies by flake.nix.
set -euo pipefail

usage() {
  cat <<'EOF'
Usage: update-local-packages [--flake DIR] [--build] [PACKAGE ... | --all]
       update-local-packages --list

Update local GitHub package pins and source/dependency hashes using nix-update.
With no package names, update all supported packages. Run in the flake checkout
(or use --flake DIR or NH_FLAKE). This edits files; review the diff and switch
with nh afterwards. It does not commit, push, or switch the system.
Progress, commands, download logs, elapsed times, and file changes are printed.

--build       Also build each updated package (SweetPad includes the extension).
--list        Show supported packages and their update policies.
--all         Update all supported packages.
--flake DIR   Local flake checkout to edit.
--help        Show this help.
EOF
}

list_packages() {
  cat <<'EOF'
althea             latest commit on the default branch
singularcard       latest commit on the default branch
sweetpad           latest commit on codex/windows-remote-testing; CLI + extension
t3code             latest published nightly; source + pnpm dependencies
auto-rob           latest stable release from Nailington/auto-rob
google-sans        latest stable release
google-sans-flex   latest stable release
twitch-drops-miner current dev-build ZIP; refresh hash even if version is unchanged
EOF
}

all_packages=(althea singularcard sweetpad t3code auto-rob google-sans google-sans-flex twitch-drops-miner)
packages=()
build=false
all=false
flake_dir="${NH_FLAKE:-}"

while (($#)); do
  case "$1" in
    --help|-h) usage; exit 0 ;;
    --list) list_packages; exit 0 ;;
    --build) build=true; shift ;;
    --all) all=true; shift ;;
    --flake)
      if (($# < 2)); then
        echo "--flake requires a local directory" >&2
        exit 2
      fi
      flake_dir="$2"
      shift 2
      ;;
    -*) echo "Unknown option: $1" >&2; usage >&2; exit 2 ;;
    *) packages+=("$1"); shift ;;
  esac
done

if "$all" && ((${#packages[@]})); then
  echo "Use either --all or package names." >&2
  exit 2
fi
if ((${#packages[@]} == 0)); then
  packages=("${all_packages[@]}")
fi
# Validate the entire selection before making any changes.
for package in "${packages[@]}"; do
  case "$package" in
    althea|singularcard|sweetpad|t3code|auto-rob|google-sans|google-sans-flex|twitch-drops-miner) ;;
    *) echo "Unsupported package: $package (see --list)" >&2; exit 2 ;;
  esac
done

if [[ -z "$flake_dir" ]]; then
  flake_dir="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
fi
cd -- "$flake_dir"
if [[ ! -f flake.nix || ! -d pkgs ]]; then
  echo "Expected this flake's local checkout; use --flake DIR." >&2
  exit 2
fi

# Flush Python's progress output immediately, including when redirected to a log.
# The packaged nix-update tees captured hash-fetching stderr when this is set.
export PYTHONUNBUFFERED=1
export NIX_UPDATE_STREAM_LOGS=1
run_command() {
  printf '[%s] Running:' "$(date +%T)"
  printf ' %q' "$@"
  printf '\n'
  "$@"
}

printf 'Checkout: %s\nPackages: %s\n' "$PWD" "${packages[*]}"
if "$build"; then
  echo 'Mode: refresh pins and hashes, then build applications.'
else
  echo 'Mode: refresh pins and hashes; application builds are disabled.'
fi
echo 'Downloads are saved in the Nix store; cached data may be reused.'
echo 'Hash-fetching logs can include an expected hash mismatch with a "got:" hash.'
echo 'nix-update uses that hash to update the package definition.'
total_started=$SECONDS

# Keep pre-existing edits if an update fails or is interrupted. Back up the
# current file, never git HEAD; each package's changes are kept only on success.
backup_dir="$(mktemp -d)"
active_file=""
cleanup() {
  if [[ -n "$active_file" ]]; then
    cp -p -- "$backup_dir/package.nix" "$active_file"
  fi
  rm -rf -- "$backup_dir"
}
trap cleanup EXIT
trap 'exit 130' INT
trap 'exit 143' TERM

failed=()
package_index=0
for package in "${packages[@]}"; do
  package_index=$((package_index + 1))
  package_started=$SECONDS
  attr="$package"
  file="pkgs/$package/default.nix"
  args=(--flake --system x86_64-linux)
  case "$package" in
    althea|singularcard)
      args+=(--version=branch)
      downloads='GitHub source archive at the latest default-branch commit'
      ;;
    sweetpad)
      args+=(--version=branch=codex/windows-remote-testing --subpackage vscodeExtension)
      downloads='GitHub source archive from codex/windows-remote-testing, npm packages, and Rust crates'
      ;;
    t3code)
      attr=t3code.unwrapped
      file=flake.nix
      args+=(--version=unstable --version-regex 'v?([0-9].*-nightly\..*)' --use-github-releases)
      downloads='GitHub source archive for the latest published nightly and pnpm packages'
      ;;
    auto-rob)
      attr=auto-rob.unwrapped
      downloads='published Electron application ZIP from the latest stable GitHub release'
      ;;
    google-sans|google-sans-flex)
      downloads='font ZIP from the latest stable GitHub release'
      ;;
    twitch-drops-miner)
      # The tag and URL stay fixed while upstream replaces the ZIP. Always
      # prefetch the original download, rather than checking release versions
      # or trying to hash the extracted AppImage used by the runtime wrapper.
      args+=(--version=skip --no-src --custom-dep zip)
      downloads='current dev-build AppImage ZIP; rehash even when the version is unchanged'
      ;;
  esac
  args+=(--override-filename "$file")
  if "$build"; then
    args+=(--build)
  fi

  printf '\n[%s] [%d/%d] Updating %s\n' "$(date +%T)" "$package_index" "${#packages[@]}" "$package"
  printf '  File: %s\n  Downloads when needed: %s\n' "$file" "$downloads"
  cp -p -- "$file" "$backup_dir/package.nix"
  active_file="$file"
  package_failed=false
  if run_command nix-update "${args[@]}" "$attr"; then
    # nix-update --build builds the CLI; verify the extension separately too.
    if [[ "$package" == sweetpad ]] && "$build" && ! run_command nix build --no-link --print-build-logs .#sweetpad-vscode; then
      cp -p -- "$backup_dir/package.nix" "$file"
      failed+=("$package")
      package_failed=true
      echo "Failed to build the SweetPad extension; restored $file." >&2
    fi
  else
    cp -p -- "$backup_dir/package.nix" "$file"
    failed+=("$package")
    package_failed=true
    echo "Failed to update $package; restored $file." >&2
  fi
  active_file=""
  if "$package_failed"; then
    printf '[%s] %s failed after %ds; original file restored.\n' "$(date +%T)" "$package" "$((SECONDS - package_started))" >&2
  else
    if cmp -s -- "$backup_dir/package.nix" "$file"; then
      echo '  No file changes.'
    else
      echo '  Changes made by this update:'
      diff -u --label "before/$file" --label "after/$file" "$backup_dir/package.nix" "$file" || true
    fi
    printf '[%s] Finished %s in %ds.\n' "$(date +%T)" "$package" "$((SECONDS - package_started))"
  fi
done

printf '\nFinished %d package(s) in %ds; %d failed.\n' "${#packages[@]}" "$((SECONDS - total_started))" "${#failed[@]}"
echo "Review changes with: git diff"
if ((${#failed[@]})); then
  printf 'Failed packages: %s\n' "${failed[*]}" >&2
  exit 1
fi
