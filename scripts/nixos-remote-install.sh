#!/usr/bin/env bash
# Remote NixOS install helper (on PATH after roundabout switch).
# For hosts in this flake: keygen → GitHub POST → agenix → git commit/push → nixos-anywhere.
#
#   nixos-remote-install --flake .#abacab root@<iso-ip>
#
# Needs: ~/.ssh/id_ed25519, secrets/github.age
# Skip prep: NIXOS_REMOTE_INSTALL_SKIP_SECRETS=1 nixos-remote-install ...
set -euo pipefail

REAL="${NIXOS_ANYWHERE_REAL:-nixos-anywhere}"

FLAKE_REF=""
args=("$@")
i=0
while [[ $i -lt ${#args[@]} ]]; do
  case "${args[$i]}" in
    --flake)
      FLAKE_REF="${args[$((i + 1))]:-}"
      i=$((i + 2))
      continue
      ;;
    --flake=*)
      FLAKE_REF="${args[$i]#--flake=}"
      i=$((i + 1))
      continue
      ;;
    --help|-h)
      echo "nixos-remote-install — flake host install (keys, GitHub, agenix, then nixos-anywhere)" >&2
      echo "  nixos-remote-install --flake .#<host> root@<iso-ip>" >&2
      echo >&2
      exec "$REAL" --help
      ;;
  esac
  i=$((i + 1))
done

HOST="${FLAKE_REF##*#}"
FLAKE_PATH="${FLAKE_REF%%#*}"
if [[ -z "$FLAKE_REF" || "$HOST" == "$FLAKE_REF" ]]; then
  echo "usage: nixos-remote-install --flake .#<host> root@<iso-ip>" >&2
  exit 2
fi

if [[ "$FLAKE_PATH" == "." || -z "$FLAKE_PATH" ]]; then
  FLAKE_ROOT="${FLAKE_ROOT:-$(git rev-parse --show-toplevel 2>/dev/null || pwd)}"
else
  FLAKE_ROOT="$FLAKE_PATH"
fi
cd "$FLAKE_ROOT"

if [[ ! -f flake.nix || ! -d "hosts/${HOST}" ]]; then
  echo "No hosts/${HOST} in ${FLAKE_ROOT}" >&2
  exit 1
fi

if [[ "${NIXOS_REMOTE_INSTALL_SKIP_SECRETS:-}" == 1 ]]; then
  exec "$REAL" "$@"
fi

STAGING="$(mktemp -d "${TMPDIR:-/tmp}/nixos-remote-install-${HOST}.XXXXXX")"
trap 'rm -rf "$STAGING"' EXIT

SECRET_DIR="secrets/ssh/${HOST}"
GITHUB_SECRET="secrets/github.age"
AGE_IDENTITY="${AGE_IDENTITY:-$HOME/.ssh/id_ed25519}"
AGE_RECIPIENT="${AGE_RECIPIENT:-$HOME/.ssh/id_ed25519.pub}"
KEY_TITLE="potter@${HOST}"

if [[ ! -f "$AGE_IDENTITY" || ! -f "$AGE_RECIPIENT" ]]; then
  echo "Need installer SSH key at ${AGE_IDENTITY} (+ .pub) to encrypt secrets / call GitHub." >&2
  exit 1
fi

if [[ ! -f "$GITHUB_SECRET" ]]; then
  echo "Create secrets/github.age first (GitHub PAT, encrypted to your installer pubkey):" >&2
  echo "  printf '%s' 'ghp_YOUR_PAT' | age -e -R ${AGE_RECIPIENT} -o ${GITHUB_SECRET}" >&2
  echo "  git add ${GITHUB_SECRET} && git commit" >&2
  echo "PAT: write:public_key (+ repo if HTTPS push fallback)." >&2
  exit 1
fi

GH_TOKEN="$(age -d -i "$AGE_IDENTITY" "$GITHUB_SECRET")"
if [[ -z "$GH_TOKEN" ]]; then
  echo "Failed to decrypt ${GITHUB_SECRET}" >&2
  exit 1
fi

mkdir -p "$STAGING/keys" "$STAGING/extra/home/potter/.ssh" "$STAGING/extra/etc/ssh"

REUSED=0
if [[ -f "${SECRET_DIR}/id_ed25519.age" && -f "${SECRET_DIR}/ssh_host_ed25519_key.age" ]]; then
  echo "==> reusing agenix keys for ${HOST}"
  REUSED=1
  age -d -i "$AGE_IDENTITY" "${SECRET_DIR}/id_ed25519.age" >"$STAGING/keys/id_ed25519"
  age -d -i "$AGE_IDENTITY" "${SECRET_DIR}/ssh_host_ed25519_key.age" >"$STAGING/keys/ssh_host_ed25519_key"
  if [[ -f "${SECRET_DIR}/id_ed25519.pub" ]]; then
    cp "${SECRET_DIR}/id_ed25519.pub" "$STAGING/keys/id_ed25519.pub"
  else
    ssh-keygen -y -f "$STAGING/keys/id_ed25519" >"$STAGING/keys/id_ed25519.pub"
  fi
  if [[ -f "${SECRET_DIR}/ssh_host_ed25519_key.pub" ]]; then
    cp "${SECRET_DIR}/ssh_host_ed25519_key.pub" "$STAGING/keys/ssh_host_ed25519_key.pub"
  else
    ssh-keygen -y -f "$STAGING/keys/ssh_host_ed25519_key" >"$STAGING/keys/ssh_host_ed25519_key.pub"
  fi
  chmod 600 "$STAGING/keys/id_ed25519" "$STAGING/keys/ssh_host_ed25519_key"
else
  echo "==> create SSH keypair for ${HOST}"
  ssh-keygen -t ed25519 -N "" -C "$KEY_TITLE" -f "$STAGING/keys/id_ed25519"
  ssh-keygen -t ed25519 -N "" -C "${HOST} host" -f "$STAGING/keys/ssh_host_ed25519_key"
fi

USER_PUB="$(tr -d '\r' <"$STAGING/keys/id_ed25519.pub" | head -n1)"

if [[ "$REUSED" -eq 0 ]]; then
  echo "==> upload public key to GitHub (${KEY_TITLE})"
  POST_BODY="$(jq -n --arg title "$KEY_TITLE" --arg key "$USER_PUB" '{title:$title,key:$key}')"
  POST_STATUS="$(curl -sS -o "$STAGING/github.body" -w '%{http_code}' -X POST \
    "https://api.github.com/user/keys" \
    -H "Authorization: Bearer ${GH_TOKEN}" \
    -H "Accept: application/vnd.github+json" \
    -H "X-GitHub-Api-Version: 2026-03-10" \
    -d "$POST_BODY" || true)"
  if [[ "$POST_STATUS" == "201" ]]; then
    echo "    GitHub: created ${KEY_TITLE}"
  elif [[ "$POST_STATUS" == "422" ]]; then
    echo "    GitHub: already present (ok)"
  else
    echo "    GitHub POST /user/keys failed (HTTP ${POST_STATUS:-?})" >&2
    cat "$STAGING/github.body" >&2 || true
    exit 1
  fi

  echo "==> store private keys in agenix"
  mkdir -p "$SECRET_DIR"
  umask 077
  cp "$STAGING/keys/id_ed25519.pub" "${SECRET_DIR}/id_ed25519.pub"
  cp "$STAGING/keys/ssh_host_ed25519_key.pub" "${SECRET_DIR}/ssh_host_ed25519_key.pub"
  age -e -R "$AGE_RECIPIENT" -o "${SECRET_DIR}/id_ed25519.age" "$STAGING/keys/id_ed25519"
  age -e -R "$AGE_RECIPIENT" -o "${SECRET_DIR}/ssh_host_ed25519_key.age" "$STAGING/keys/ssh_host_ed25519_key"
fi

echo "==> re-encrypt secrets to current GitHub .keys"
sleep 2
sync-age-recipients

install -m 700 -d "$STAGING/extra/home/potter/.ssh"
install -m 600 "$STAGING/keys/id_ed25519" "$STAGING/extra/home/potter/.ssh/id_ed25519"
install -m 644 "$STAGING/keys/id_ed25519.pub" "$STAGING/extra/home/potter/.ssh/id_ed25519.pub"
install -m 600 "$STAGING/keys/ssh_host_ed25519_key" "$STAGING/extra/etc/ssh/ssh_host_ed25519_key"
install -m 644 "$STAGING/keys/ssh_host_ed25519_key.pub" "$STAGING/extra/etc/ssh/ssh_host_ed25519_key.pub"

echo "==> commit + push flake"
git add -- "$SECRET_DIR" secrets.nix secrets/recipients.nix 2>/dev/null || git add -- "$SECRET_DIR"
if ! git diff --cached --quiet; then
  git commit -m "Add SSH keys for ${HOST}"
fi

push_flake() {
  local origin ssh_origin https_origin
  origin="$(git remote get-url origin)"
  ssh_origin="$origin"
  if [[ "$origin" == https://github.com/* ]]; then
    ssh_origin="git@github.com:${origin#https://github.com/}"
    ssh_origin="${ssh_origin%.git}.git"
  fi
  export GIT_SSH_COMMAND="ssh -i ${AGE_IDENTITY} -o IdentitiesOnly=yes -o StrictHostKeyChecking=accept-new"
  if ! git push "$ssh_origin" HEAD; then
    echo "    SSH push failed; trying HTTPS with PAT"
    https_origin="$origin"
    if [[ "$https_origin" != https://* ]]; then
      https_origin="https://github.com/${ssh_origin#git@github.com:}"
    fi
    git push "https://x-access-token:${GH_TOKEN}@${https_origin#https://}" HEAD
  fi
}
push_flake

HW_ARGS=()
has_hw=0
has_extra=0
for a in "$@"; do
  [[ "$a" == --generate-hardware-config ]] && has_hw=1
  [[ "$a" == --extra-files ]] && has_extra=1
done
if [[ "$has_hw" -eq 0 ]]; then
  HW_ARGS+=(--generate-hardware-config nixos-generate-config "hosts/${HOST}/hardware-configuration.nix")
fi
EXTRA_ARGS=()
if [[ "$has_extra" -eq 0 ]]; then
  EXTRA_ARGS+=(--extra-files "$STAGING/extra")
fi

echo "==> nixos-anywhere install ${HOST}"
"$REAL" "${EXTRA_ARGS[@]}" "${HW_ARGS[@]}" "$@"

if [[ -f "hosts/${HOST}/hardware-configuration.nix" ]]; then
  git add -- "hosts/${HOST}/hardware-configuration.nix"
  if ! git diff --cached --quiet; then
    git commit -m "hardware-configuration for ${HOST}"
    push_flake
  fi
fi

echo "==> done. ssh potter@<ip>  (TOFU host key once; login via GitHub .keys)"
