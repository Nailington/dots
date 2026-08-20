#!/usr/bin/env bash
# Fetch GitHub SSH pubs + known host pubs. Re-encrypt + commit only when a new key appears.
# Run from nixos-remote-install or as `sync-age-recipients` on PATH (nh os switch).
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

# GitHub-only snapshot for sshd authorized_keys (host pubs must not go there).
cp "$STAGING/github.keys" "$STAGING/github-login.keys"

# Also keep host keys so servers can decrypt at activation via ssh_host_ed25519_key.
if [[ -d secrets/ssh ]]; then
  find secrets/ssh -name 'ssh_host_ed25519_key.pub' -print0 2>/dev/null \
    | xargs -0 -r cat >>"$STAGING/github.keys" || true
fi
if [[ -f lib/ssh-keys.nix ]]; then
  nix eval --raw --impure --expr '(import ./lib/ssh-keys.nix).roundaboutPub' >>"$STAGING/github.keys"
  echo >>"$STAGING/github.keys"
fi

py_rc=0
python3 - "$STAGING/github-login.keys" "$STAGING/github.keys" "$RECIPIENTS_FILE" secrets/recipients.nix secrets/github-login-keys.nix <<'PY' || py_rc=$?
from pathlib import Path
import re
import sys

login_raw, all_raw, rec_path, rec_nix, login_nix = sys.argv[1:]


def ident(line):
    parts = line.split()
    if len(parts) < 2:
        return None
    return parts[0] + " " + parts[1]


def keys_from_raw(text):
    keys = []
    seen = set()
    for line in text.splitlines():
        line = line.strip()
        if not line or line.startswith("#"):
            continue
        i = ident(line)
        if i is None or i in seen:
            continue
        seen.add(i)
        keys.append(line)
    return keys


def idents_from_nix(path):
    p = Path(path)
    seen = set()
    keys = []
    if not p.exists():
        return seen, keys
    for quoted in re.findall(r'"([^"]+)"', p.read_text()):
        i = ident(quoted)
        if i is None or i in seen:
            continue
        seen.add(i)
        keys.append(quoted)
    return seen, keys


def write_nix_list(path, keys):
    Path(path).parent.mkdir(parents=True, exist_ok=True)
    Path(path).write_text("[\n" + "".join(f'  "{k}"\n' for k in keys) + "]\n")


login_keys = keys_from_raw(Path(login_raw).read_text())
old_login_seen, _ = idents_from_nix(login_nix)
login_changed = {ident(k) for k in login_keys} != old_login_seen
if login_changed:
    write_nix_list(login_nix, login_keys)
    print(f"    {len(login_keys)} GitHub login key(s) -> {login_nix}")
else:
    print("    GitHub login keys unchanged")

old_seen, old_keys = idents_from_nix(rec_nix)
fetched = keys_from_raw(Path(all_raw).read_text())
if not fetched and not old_keys:
    raise SystemExit("no recipient keys found")

new_keys = [k for k in fetched if ident(k) not in old_seen]
if new_keys:
    print(f"    {len(new_keys)} new age recipient(s):")
    for k in new_keys:
        print(f"      {k}")
    all_keys = old_keys + new_keys
    Path(rec_path).write_text("".join(k + "\n" for k in all_keys))
    rec_file = Path(rec_nix)
    rec_file.parent.mkdir(parents=True, exist_ok=True)
    if rec_file.exists():
        stripped = rec_file.read_text().rstrip()
        if stripped.endswith("]"):
            body = stripped[:-1].rstrip() + "\n"
            extra = "".join(f'  "{k}"\n' for k in new_keys)
            rec_file.write_text(body + extra + "]\n")
        else:
            write_nix_list(rec_nix, all_keys)
    else:
        write_nix_list(rec_nix, all_keys)
    raise SystemExit(0)

print("    no new age recipients")
raise SystemExit(3 if login_changed else 2)
PY

if [[ "$py_rc" -eq 2 ]]; then
  echo "==> no new keys; skip re-encrypt/commit"
  exit 0
fi
if [[ "$py_rc" -ne 0 && "$py_rc" -ne 3 ]]; then
  exit "$py_rc"
fi

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
  local msg=""
  if [[ -r /dev/tty ]]; then
    printf 'Commit message [Sync age recipients] (30s): ' >/dev/tty
    if ! IFS= read -r -t 30 msg </dev/tty; then
      printf '\n' >/dev/tty
      msg=""
    fi
  fi
  msg="${msg:-Sync age recipients}"
  git commit -m "$msg"

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

if [[ "$py_rc" -eq 3 ]]; then
  echo "==> GitHub login keys updated; skip age re-encrypt"
  git add -- secrets/github-login-keys.nix 2>/dev/null || true
  commit_and_push_secrets
  exit 0
fi

shopt -s globstar nullglob
AGE_FILES=(secrets/**/*.age)
if [[ ${#AGE_FILES[@]} -eq 0 ]]; then
  echo "==> no .age files yet; wrote secrets/recipients.nix only"
  git add -- secrets/recipients.nix secrets/github-login-keys.nix 2>/dev/null || true
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

git add -- secrets/recipients.nix secrets/github-login-keys.nix "${AGE_FILES[@]}"
commit_and_push_secrets
