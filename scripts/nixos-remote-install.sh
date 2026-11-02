#!/usr/bin/env bash
# Remote NixOS install helper (on PATH after roundabout switch).
# Prepare keys locally, publish only the user PUBLIC key to GitHub, store encrypted
# private keys, sync recipients, then pass the keys to nixos-anywhere for first boot.
# This script commits and pushes; run with no unrelated staged changes.
# Full flow: docs/agents/secrets-and-ssh.md.
#
#   nixos-remote-install --flake .#abacab root@<iso-ip>
#
# Needs: ~/.ssh/id_ed25519, secrets/github.age
# Skip prep: NIXOS_REMOTE_INSTALL_SKIP_SECRETS=1 nixos-remote-install ...
# SD image creation: --prepare-only <private-directory> enrolls keys without installation.
set -euo pipefail

REAL="${NIXOS_ANYWHERE_REAL:-nixos-anywhere}"

FLAKE_REF=""
PREPARE_ONLY=""
args=("$@")
i=0
while [[ $i -lt ${#args[@]} ]]; do
  case "${args[$i]}" in
    --prepare-only)
      PREPARE_ONLY="${args[$((i + 1))]:-}"
      [[ -n "$PREPARE_ONLY" ]] || { echo "--prepare-only needs a private output directory" >&2; exit 2; }
      i=$((i + 2))
      continue
      ;;
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
      echo "  nixos-remote-install --flake .#<host> --prepare-only <private-directory>" >&2
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

if [[ -n "$PREPARE_ONLY" ]]; then
  PREPARE_ONLY="$(realpath -m -- "$PREPARE_ONLY")"
  case "$PREPARE_ONLY/" in
    "$(pwd -P)/"*|/nix/store/*) echo "Prepared private keys must stay outside the flake and Nix store." >&2; exit 1 ;;
  esac
  if [[ -e "$PREPARE_ONLY" || -L "$PREPARE_ONLY" ]]; then
    echo "Refusing to overwrite --prepare-only destination: ${PREPARE_ONLY}" >&2
    exit 1
  fi
  if ! git diff --cached --quiet; then
    echo "Keep the Git index empty before enrollment; unrelated staged changes must not be committed." >&2
    exit 1
  fi
  scratch="$(realpath -- "${TMPDIR:-/tmp}")"
  case "$scratch/" in
    "$(pwd -P)/"*|/nix/store/*) echo "TMPDIR must keep private keys outside the flake and Nix store." >&2; exit 1 ;;
  esac
fi

if [[ "${NIXOS_REMOTE_INSTALL_SKIP_SECRETS:-}" == 1 ]]; then
  [[ -z "$PREPARE_ONLY" ]] || { echo "--prepare-only cannot skip key enrollment" >&2; exit 1; }
  exec "$REAL" "$@"
fi

STAGING="$(mktemp -d "${TMPDIR:-/tmp}/nixos-remote-install-${HOST}.XXXXXX")"
trap 'rm -rf "$STAGING"' EXIT

SECRET_DIR="secrets/ssh/${HOST}"
GITHUB_SECRET="secrets/github.age"
AGE_IDENTITY="${AGE_IDENTITY:-$HOME/.ssh/id_ed25519}"
AGE_RECIPIENT="${AGE_RECIPIENT:-$HOME/.ssh/id_ed25519.pub}"
KEY_TITLE="potter@${HOST}"

if [[ -f "${SECRET_DIR}/id_ed25519.age" && ! -f "${SECRET_DIR}/ssh_host_ed25519_key.age" ]] ||
   [[ ! -f "${SECRET_DIR}/id_ed25519.age" && -f "${SECRET_DIR}/ssh_host_ed25519_key.age" ]]; then
  echo "Incomplete encrypted keypair for ${HOST}; refusing to rotate an existing identity." >&2
  exit 1
fi
if [[ -n "$PREPARE_ONLY" && ! -f "${SECRET_DIR}/id_ed25519.age" ]] &&
   [[ -f "${SECRET_DIR}/id_ed25519.pub" || -f "${SECRET_DIR}/ssh_host_ed25519_key.pub" ]]; then
  echo "Public keys already exist for ${HOST} without private-key backups; refusing to replace them." >&2
  exit 1
fi

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

# github.age contains a GitHub API token, NOT an SSH private key.
# The token uploads to its owning GitHub account; never print it.
GH_TOKEN="$(age -d -i "$AGE_IDENTITY" "$GITHUB_SECRET")"
if [[ -z "$GH_TOKEN" ]]; then
  echo "Failed to decrypt ${GITHUB_SECRET}" >&2
  exit 1
fi

mkdir -p "$STAGING/keys" "$STAGING/extra/home/potter/.ssh" "$STAGING/extra/etc/ssh"

# Reinstall: reuse the stored pair only when both encrypted private keys exist.
# Otherwise generate a user key (outgoing SSH) and a host key (server identity).
REUSED=0
if [[ -f "${SECRET_DIR}/id_ed25519.age" && -f "${SECRET_DIR}/ssh_host_ed25519_key.age" ]]; then
  echo "==> reusing agenix keys for ${HOST}"
  REUSED=1
  age -d -i "$AGE_IDENTITY" "${SECRET_DIR}/id_ed25519.age" >"$STAGING/keys/id_ed25519"
  age -d -i "$AGE_IDENTITY" "${SECRET_DIR}/ssh_host_ed25519_key.age" >"$STAGING/keys/ssh_host_ed25519_key"
  chmod 600 "$STAGING/keys/id_ed25519" "$STAGING/keys/ssh_host_ed25519_key"
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
else
  echo "==> create SSH keypair for ${HOST}"
  ssh-keygen -t ed25519 -N "" -C "$KEY_TITLE" -f "$STAGING/keys/id_ed25519"
  ssh-keygen -t ed25519 -N "" -C "${HOST} host" -f "$STAGING/keys/ssh_host_ed25519_key"
fi

for key in id_ed25519 ssh_host_ed25519_key; do
  derived="$(ssh-keygen -y -f "$STAGING/keys/$key")"
  read -r key_type key_blob _ <<<"$derived"
  derived="$key_type $key_blob"
  read -r key_type key_blob _ <"$STAGING/keys/$key.pub"
  recorded="$key_type $key_blob"
  if [[ "$derived" != "$recorded" ]]; then
    echo "Public/private key mismatch for ${HOST}: ${key}" >&2
    exit 1
  fi
  if [[ "$REUSED" -eq 1 && ! -f "${SECRET_DIR}/$key.pub" ]]; then
    cp "$STAGING/keys/$key.pub" "${SECRET_DIR}/$key.pub"
  fi
done

USER_PUB="$(tr -d '\r' <"$STAGING/keys/id_ed25519.pub" | head -n1)"

if [[ "$REUSED" -eq 0 || -n "$PREPARE_ONLY" ]]; then
  echo "==> ensure user public key is on GitHub (${KEY_TITLE})"
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
    curl -fsS --max-time 30 \
      "https://api.github.com/user/keys?per_page=100" \
      -H "Authorization: Bearer ${GH_TOKEN}" \
      -H "Accept: application/vnd.github+json" >"$STAGING/registered.keys"
    if ! jq -e --arg key "$USER_PUB" 'any(.[]; (.key | split(" ")[0:2]) == ($key | split(" ")[0:2]))' \
      "$STAGING/registered.keys" >/dev/null; then
      echo "GitHub rejected the key and it is not registered on the token's account." >&2
      exit 1
    fi
    echo "    GitHub: existing key verified"
  else
    echo "    GitHub POST /user/keys failed (HTTP ${POST_STATUS:-?})" >&2
    cat "$STAGING/github.body" >&2 || true
    exit 1
  fi

fi

if [[ "$REUSED" -eq 0 ]]; then
  echo "==> store private keys in agenix"
  mkdir -p "$SECRET_DIR"
  umask 077
  cp "$STAGING/keys/id_ed25519.pub" "${SECRET_DIR}/id_ed25519.pub"
  cp "$STAGING/keys/ssh_host_ed25519_key.pub" "${SECRET_DIR}/ssh_host_ed25519_key.pub"
  # Bootstrap encryption to the installer first; sync adds GitHub + host recipients.
  age -e -R "$AGE_RECIPIENT" -o "${SECRET_DIR}/id_ed25519.age" "$STAGING/keys/id_ed25519"
  age -e -R "$AGE_RECIPIENT" -o "${SECRET_DIR}/ssh_host_ed25519_key.age" "$STAGING/keys/ssh_host_ed25519_key"
fi

echo "==> re-encrypt secrets to current GitHub .keys"
sleep 2
sync-age-recipients

if [[ -n "$PREPARE_ONLY" ]]; then
  # sync may return successfully without re-encryption on a new/untrusted builder.
  # Fail rather than produce an image that cannot decrypt on its first boot.
  while IFS= read -r -d '' secret; do
    if ! age -d -i "$STAGING/keys/ssh_host_ed25519_key" "$secret" >/dev/null; then
      echo "${HOST} cannot decrypt ${secret}; enroll from a trusted host such as roundabout." >&2
      exit 1
    fi
  done < <(find secrets -name '*.age' -type f -print0)
  read -r _ user_blob _ <"$STAGING/keys/id_ed25519.pub"
  if [[ ! -f secrets/github-login-keys.nix ]] || [[ "$(<secrets/github-login-keys.nix)" != *"$user_blob"* ]]; then
    echo "GitHub's login snapshot does not yet include ${HOST}; rerun enrollment after the key becomes visible." >&2
    exit 1
  fi
fi

# Put decrypted keys into the installer payload so the new host can decrypt
# its age store on its very first activation. These plaintext files stay in STAGING.
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
    # Let Git request the token privately; never put it in a URL/error message.
    # shellcheck disable=SC2016
    NIXOS_INSTALL_GITHUB_TOKEN="$GH_TOKEN" git \
      -c credential.helper= \
      -c 'credential.helper=!f() { if [ "$1" = get ]; then printf "%s\n" "username=x-access-token" "password=$NIXOS_INSTALL_GITHUB_TOKEN"; fi; }; f' \
      push "$https_origin" HEAD
  fi
}
push_flake

if [[ -n "$PREPARE_ONLY" ]]; then
  install -d -m 700 "$PREPARE_ONLY"
  cp -a -- "$STAGING/extra/." "$PREPARE_ONLY/"
  echo "==> enrolled ${HOST}; private provisioning files prepared outside the flake"
  exit 0
fi

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
