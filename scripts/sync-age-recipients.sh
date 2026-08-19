#!/usr/bin/env bash
# Fetch GitHub SSH pubs + known host pubs, re-encrypt every secrets/**/*.age to that set.
# Run from nixos-remote-install or as `sync-age-recipients` on PATH (nh os switch).
# Commits + pushes secret changes so other hosts pick them up.
set -euo pipefail

FLAKE_ROOT="${FLAKE_ROOT:-$(git rev-parse --show-toplevel 2>/dev/null || pwd)}"
cd "$FLAKE_ROOT"
if [[ ! -f flake.nix ]]; then
  echo "Run from the flake root (or set FLAKE_ROOT)." >&2
  exit 1
fi

AGE_IDENTITY="${AGE_IDENTITY:-$HOME/.ssh/id_ed25519}"
if [[ ! -f "$AGE_IDENTITY" && -f /etc/ssh/ssh_host_ed25519_key ]]; then
  AGE_IDENTITY=/etc/ssh/ssh_host_ed25519_key
fi
if [[ ! -f "$AGE_IDENTITY" ]]; then
  echo "No age identity (need ~/.ssh/id_ed25519 or /etc/ssh/ssh_host_ed25519_key)" >&2
  exit 1
fi

mapfile -t GH_USERS < <(nix eval --raw --impure --expr '
  let users = import ./lib/github-users.nix;
  in builtins.concatStringsSep "\n" users
')

STAGING="$(mktemp -d "${TMPDIR:-/tmp}/sync-age.XXXXXX")"
trap 'rm -rf "$STAGING"' EXIT
RECIPIENTS_FILE="$STAGING/recipients"

: >"$RECIPIENTS_FILE"

echo "==> fetching GitHub SSH pubs"
for gh_user in "${GH_USERS[@]}"; do
  echo "    https://github.com/${gh_user}.keys"
  curl -fsSL --max-time 15 \
    -H "Accept: application/vnd.github+json" \
    -H "X-GitHub-Api-Version: 2026-03-10" \
    "https://github.com/${gh_user}.keys" >>"$STAGING/github.keys" || {
    echo "failed to fetch keys for ${gh_user}" >&2
    exit 1
  }
  echo >>"$STAGING/github.keys"
done

# Also keep host keys so servers can decrypt at activation via ssh_host_ed25519_key.
if [[ -d secrets/ssh ]]; then
  find secrets/ssh -name 'ssh_host_ed25519_key.pub' -print0 2>/dev/null \
    | xargs -0 -r cat >>"$STAGING/github.keys" || true
fi
if [[ -f lib/ssh-keys.nix ]]; then
  nix eval --raw --impure --expr '(import ./lib/ssh-keys.nix).roundaboutPub' >>"$STAGING/github.keys"
  echo >>"$STAGING/github.keys"
fi

python3 - "$STAGING/github.keys" "$RECIPIENTS_FILE" secrets/recipients.nix <<'PY'
from pathlib import Path
import sys

raw, rec_path, nix_path = sys.argv[1:]
seen = set()
keys = []
for line in Path(raw).read_text().splitlines():
    line = line.strip()
    if not line or line.startswith("#"):
        continue
    parts = line.split()
    if len(parts) < 2:
        continue
    ident = parts[0] + " " + parts[1]
    if ident in seen:
        continue
    seen.add(ident)
    keys.append(line)

if not keys:
    raise SystemExit("no recipient keys found")

Path(rec_path).write_text("".join(k + "\n" for k in keys))
nix = "[\n" + "".join(f'  "{k}"\n' for k in keys) + "]\n"
Path(nix_path).parent.mkdir(parents=True, exist_ok=True)
Path(nix_path).write_text(nix)
print(f"    {len(keys)} unique recipients -> secrets/recipients.nix")
PY

shopt -s globstar nullglob
AGE_FILES=(secrets/**/*.age)
commit_and_push_secrets() {
  if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    echo "==> not a git checkout; skip commit/push" >&2
    return 0
  fi
  if git diff --cached --quiet; then
    echo "==> no secret changes to commit"
    return 0
  fi

  echo "==> commit age recipients"
  git commit -m "Sync age recipients"

  local origin ssh_origin
  origin="$(git remote get-url origin 2>/dev/null || true)"
  if [[ -z "$origin" ]]; then
    echo "==> no git remote 'origin'; skip push" >&2
    return 0
  fi
  ssh_origin="$origin"
  if [[ "$origin" == https://github.com/* ]]; then
    ssh_origin="git@github.com:${origin#https://github.com/}"
    ssh_origin="${ssh_origin%.git}.git"
  fi
  echo "==> push ${ssh_origin}"
  export GIT_SSH_COMMAND="ssh -i ${AGE_IDENTITY} -o IdentitiesOnly=yes -o StrictHostKeyChecking=accept-new"
  git push "$ssh_origin" HEAD
}

if [[ ${#AGE_FILES[@]} -eq 0 ]]; then
  echo "==> no .age files yet; wrote secrets/recipients.nix only"
  git add -- secrets/recipients.nix 2>/dev/null || true
  commit_and_push_secrets
  exit 0
fi

echo "==> re-encrypting ${#AGE_FILES[@]} secret(s) to current GitHub + host pubs"
for f in "${AGE_FILES[@]}"; do
  echo "    $f"
  age -d -i "$AGE_IDENTITY" "$f" >"$STAGING/plain"
  age -e -R "$RECIPIENTS_FILE" -o "$STAGING/out.age" "$STAGING/plain"
  mv "$STAGING/out.age" "$f"
  rm -f "$STAGING/plain"
done

git add -- secrets/recipients.nix "${AGE_FILES[@]}"
commit_and_push_secrets
