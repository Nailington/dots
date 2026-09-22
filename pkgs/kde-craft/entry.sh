#!/usr/bin/env bash
# Runs *inside* the kde-craft FHS sandbox.
# Invoked as: kde-craft-entry [setup|shell|craft|run] [args...]
set -euo pipefail

BOOTSTRAP="/usr/lib/kde-craft/bootstrap.py"

expand_root() {
  local raw="${CRAFT_ROOT:-$HOME/CraftRoot}"
  raw="${raw/#\~/$HOME}"
  # resolve if it exists; otherwise keep the expanded path
  if [[ -d "$raw" ]]; then
    cd "$raw" && pwd
  else
    printf '%s\n' "$raw"
  fi
}

export CRAFT_ROOT="$(expand_root)"
export CRAFT_PYTHON_BIN="${CRAFT_PYTHON_BIN:-/usr/bin/python3}"

usage() {
  cat <<EOF
KDE Craft on NixOS — FHS sandbox around a writable CraftRoot.

  craft-setup [--force]     first-time install into \$CRAFT_ROOT
  craft-shell               interactive shell with craftenv loaded
  craft <args>              run a craft command (e.g. craft kate)
  craft-run <cmd> [args]    run a Craft-built binary in this env

  nix develop .#craft       same as craft-shell
  nix run .#kde-craft -- --search kate

CraftRoot: ${CRAFT_ROOT}
Override with CRAFT_ROOT=/path (must stay outside the Nix store).

Craft keeps its own Python venv at \$CRAFT_ROOT/etc/virtualenv/3 and
clones/builds into that prefix. Always run craft and Craft-built apps
from this sandbox — they expect /usr/lib and Craft's rpaths.

Docs: https://community.kde.org/Craft
EOF
}

craft_ready() {
  [[ -f "$CRAFT_ROOT/craft/craftenv.sh" ]]
}

do_setup() {
  if [[ ! -f "$BOOTSTRAP" ]]; then
    echo "craft-setup: missing $BOOTSTRAP (is this the kde-craft FHS env?)" >&2
    exit 1
  fi
  exec "$CRAFT_PYTHON_BIN" "$BOOTSTRAP" --prefix "$CRAFT_ROOT" "$@"
}

# CraftBootstrap stores dirname(sys.executable). Inside bwrap that is still a
# /nix/store path, which vanishes after GC. Keep Craft pointed at the FHS.
pin_python_path() {
  local ini="$CRAFT_ROOT/etc/CraftSettings.ini"
  [[ -f "$ini" ]] || return 0
  if grep -qE '^Python = /nix/store/' "$ini"; then
    sed -i 's|^Python = /nix/store/.*|Python = /usr/bin|' "$ini"
    echo "craft: Paths/Python → /usr/bin (avoid pinning a Nix store path)" >&2
  fi
}

source_craftenv() {
  if ! craft_ready; then
    echo "Craft is not installed at $CRAFT_ROOT" >&2
    echo "Run: craft-setup" >&2
    exit 1
  fi
  pin_python_path

  local venv_py="$CRAFT_ROOT/etc/virtualenv/3/bin/python3"
  if [[ -e "$venv_py" && ! -x "$venv_py" ]]; then
    echo "warning: Craft venv python is broken ($venv_py)." >&2
    echo "  after a Nix Python upgrade: rm -rf \"$CRAFT_ROOT/etc/virtualenv\" && craft craft" >&2
  fi

  # craftenv.sh defines craft/cs/cb/cr and cd's to KDEROOT
  set +euo pipefail
  # shellcheck disable=SC1091
  source "$CRAFT_ROOT/craft/craftenv.sh"
  set -euo pipefail
}

do_shell() {
  if ! craft_ready; then
    usage
    echo
    echo "CraftRoot is empty. Inside this sandbox run:  craft-setup"
    echo "That clones Craft into $CRAFT_ROOT (writable; not the Nix store)."
    exec bash --norc --noprofile -i
  fi

  if [[ -n "${CRAFT_SHELL_CMD:-}" ]]; then
    source_craftenv
    exec bash -c "$CRAFT_SHELL_CMD"
  fi

  # New interactive bash must source craftenv itself — functions (craft/cs/cb/cr)
  # do not survive exec.
  local init
  init="$(mktemp --tmpdir kde-craft-bashrc.XXXXXX)"
  cat >"$init" <<EOF
[[ -f /etc/profile ]] && source /etc/profile
[[ -f "\$HOME/.bashrc" ]] && source "\$HOME/.bashrc"
# shellcheck disable=SC1091
source "$CRAFT_ROOT/craft/craftenv.sh"
export CRAFT_NIXOS=1
rm -f "$init"
echo "Craft environment ready."
echo "  CraftRoot  $CRAFT_ROOT"
echo "  craft --search kate    craft kate"
echo "  cs <pkg>  source    cb <pkg>  build    cr  CraftRoot"
EOF
  exec bash --init-file "$init" -i
}

do_craft() {
  source_craftenv
  # craft() is defined by craftenv.sh
  craft "$@"
}

do_run() {
  if [[ $# -eq 0 ]]; then
    echo "usage: craft-run <command> [args...]" >&2
    exit 2
  fi
  source_craftenv
  exec "$@"
}

mode="${1:-shell}"
case "$mode" in
  -h | --help | help)
    usage
    exit 0
    ;;
  setup)
    shift
    do_setup "$@"
    ;;
  shell)
    shift || true
    do_shell "$@"
    ;;
  craft)
    shift
    do_craft "$@"
    ;;
  run)
    shift
    do_run "$@"
    ;;
  exec)
    # raw command inside the FHS, no craftenv (used for smoke tests)
    shift
    exec "$@"
    ;;
  *)
    # `nix run .#kde-craft -- --search kate` / wrappers that skip the verb
    do_craft "$@"
    ;;
esac
