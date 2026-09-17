#!/usr/bin/env bash
# Snapshot this machine's SSH pubs, fetch GitHub SSH pubs, refresh age recipients.
# Re-encrypt + commit only when something new appears.
# Run from nixos-remote-install or as `sync-age-recipients` on PATH (nh os/darwin switch).
set -euo pipefail

FLAKE_ROOT="${FLAKE_ROOT:-$(git rev-parse --show-toplevel 2>/dev/null || pwd)}"
cd "$FLAKE_ROOT"
if [[ ! -f flake.nix ]]; then
  echo "Run from the flake root (or set FLAKE_ROOT)." >&2
  exit 1
fi

AGE_IDENTITY="${AGE_IDENTITY:-$HOME/.ssh/id_ed25519}"
if [[ ! -r "$AGE_IDENTITY" && -r /etc/ssh/ssh_host_ed25519_key ]]; then
  AGE_IDENTITY=/etc/ssh/ssh_host_ed25519_key
fi

this_host_name() {
  if [[ -n "${SYNC_AGE_HOST:-}" ]]; then
    printf '%s\n' "$SYNC_AGE_HOST"
    return
  fi
  if [[ -x /usr/sbin/scutil ]]; then
    /usr/sbin/scutil --get LocalHostName
  elif [[ -x /bin/hostname ]]; then
    /bin/hostname -s
  else
    hostname -s
  fi
}

ssh_ident() {
  local type blob
  read -r type blob _ <"$1" || return 1
  printf '%s %s\n' "$type" "$blob"
}

# Copy only when dest is missing or the key blob differs (comments/whitespace ignored).
copy_if_changed() {
  local src=$1 dest=$2
  [[ -r "$src" ]] || return 1
  mkdir -p "$(dirname "$dest")"
  if [[ -f "$dest" ]]; then
    local a b
    a="$(ssh_ident "$src")"
    b="$(ssh_ident "$dest")"
    if [[ -n "$a" && "$a" == "$b" ]]; then
      return 1
    fi
  fi
  cp "$src" "$dest"
  return 0
}

HOST="$(this_host_name)"
LOCAL_PUBS_CHANGED=0
if [[ -n "$HOST" && -d "hosts/${HOST}" ]]; then
  echo "==> snapshot ${HOST} SSH pubs into secrets/ssh/${HOST}/"
  SECRET_DIR="secrets/ssh/${HOST}"
  mkdir -p "$SECRET_DIR"
  if copy_if_changed /etc/ssh/ssh_host_ed25519_key.pub "${SECRET_DIR}/ssh_host_ed25519_key.pub"; then
    echo "    host pub -> ${SECRET_DIR}/ssh_host_ed25519_key.pub (age recipient; not for GitHub)"
    LOCAL_PUBS_CHANGED=1
  fi
  USER_PRIV="${HOME}/.ssh/id_ed25519"
  USER_PUB="${HOME}/.ssh/id_ed25519.pub"
  STORE_USER_PUB="${SECRET_DIR}/id_ed25519.pub"
  # Already in the store: do not mint a second key or overwrite the snapshot.
  if [[ -f "$STORE_USER_PUB" ]]; then
    echo "    user pub already in store; leave ${STORE_USER_PUB} alone"
  else
    if [[ ! -e "$USER_PRIV" && ! -f "$USER_PUB" ]]; then
      echo "    generating ${USER_PRIV} (potter@${HOST})"
      mkdir -p "${HOME}/.ssh"
      chmod 700 "${HOME}/.ssh"
      ssh-keygen -t ed25519 -N "" -C "potter@${HOST}" -f "$USER_PRIV"
    fi
    if copy_if_changed "$USER_PUB" "$STORE_USER_PUB"; then
      echo "    user pub -> ${STORE_USER_PUB}  (add this to GitHub)"
      LOCAL_PUBS_CHANGED=1
    fi
  fi
  if [[ -r "$USER_PRIV" && ! -r "$AGE_IDENTITY" ]]; then
    AGE_IDENTITY="$USER_PRIV"
  fi
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

stage_secret_pubs() {
  git add -- secrets/ssh/*/id_ed25519.pub secrets/ssh/*/ssh_host_ed25519_key.pub \
    2>/dev/null || true
}

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
  if [[ -r "$AGE_IDENTITY" ]]; then
    export GIT_SSH_COMMAND="ssh -i ${AGE_IDENTITY} -o IdentitiesOnly=yes -o StrictHostKeyChecking=accept-new"
  fi
  if ! git push "$ssh_origin" HEAD; then
    echo "==> push failed (new key not on GitHub yet?). Commit is local." >&2
    echo "    Add secrets/ssh/${HOST}/id_ed25519.pub to GitHub, then: git push" >&2
  fi
}

if [[ "$py_rc" -eq 2 ]]; then
  if [[ "$LOCAL_PUBS_CHANGED" -eq 1 ]]; then
    stage_secret_pubs
    if git diff --cached --quiet 2>/dev/null; then
      echo "==> no new keys; skip re-encrypt/commit"
      exit 0
    fi
    echo "==> local SSH pubs updated; commit (no re-encrypt)"
    commit_and_push_secrets
    echo "    Add secrets/ssh/${HOST}/id_ed25519.pub to GitHub, then nh os switch on roundabout to re-encrypt."
    exit 0
  fi
  echo "==> no new keys; skip re-encrypt/commit"
  exit 0
fi
if [[ "$py_rc" -ne 0 && "$py_rc" -ne 3 ]]; then
  exit "$py_rc"
fi

if [[ "$py_rc" -eq 3 ]]; then
  echo "==> GitHub login keys updated; skip age re-encrypt"
  git add -- secrets/github-login-keys.nix 2>/dev/null || true
  stage_secret_pubs
  commit_and_push_secrets
  exit 0
fi

shopt -s globstar nullglob
AGE_FILES=(secrets/**/*.age)
if [[ ${#AGE_FILES[@]} -eq 0 ]]; then
  echo "==> no .age files yet; wrote secrets/recipients.nix only"
  git add -- secrets/recipients.nix secrets/github-login-keys.nix 2>/dev/null || true
  stage_secret_pubs
  commit_and_push_secrets
  exit 0
fi

echo "==> re-encrypting ${#AGE_FILES[@]} secret(s) to current GitHub + host pubs"
if [[ ! -r "$AGE_IDENTITY" ]]; then
  echo "    no readable age identity; skip re-encrypt (run nh os switch on roundabout)" >&2
  git checkout -- secrets/recipients.nix 2>/dev/null || true
  if [[ "$LOCAL_PUBS_CHANGED" -eq 1 ]]; then
    stage_secret_pubs
    commit_and_push_secrets
  fi
  exit 0
fi

reencrypt_ok=1
for f in "${AGE_FILES[@]}"; do
  echo "    $f"
  if ! age -d -i "$AGE_IDENTITY" "$f" >"$STAGING/plain"; then
    echo "    cannot decrypt with ${AGE_IDENTITY}; skip re-encrypt (run nh os switch on roundabout)" >&2
    reencrypt_ok=0
    break
  fi
  age -e -R "$RECIPIENTS_FILE" -o "$STAGING/out.age" "$STAGING/plain"
  mv "$STAGING/out.age" "$f"
  rm -f "$STAGING/plain"
done

if [[ "$reencrypt_ok" -eq 1 ]]; then
  git add -- secrets/recipients.nix secrets/github-login-keys.nix "${AGE_FILES[@]}"
  stage_secret_pubs
  commit_and_push_secrets
else
  git checkout -- secrets/recipients.nix "${AGE_FILES[@]}" 2>/dev/null || true
  if [[ "$LOCAL_PUBS_CHANGED" -eq 1 ]]; then
    stage_secret_pubs
    commit_and_push_secrets
  fi
  echo "    Add secrets/ssh/${HOST}/id_ed25519.pub to GitHub, then nh os switch on roundabout to re-encrypt."
fi
