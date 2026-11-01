#!/usr/bin/env bash
# Enroll a flake host, build its generic SD image, then provision a private copy.
# Plaintext identities never enter a Nix derivation, the store, or the checkout.
set -euo pipefail
umask 077

die() { echo "nixos-sd-image: $*" >&2; exit 1; }
usage() {
  cat <<'EOF'
Usage: nixos-sd-image --flake .#custard --output /path/custard.img [--wifi-profile FILE]

Run on a trusted builder that can decrypt secrets/github.age and build ARM.
Enrolls/reuses SSH keys, uploads the USER public key to GitHub, updates agenix,
and commits/pushes enrollment changes through nixos-remote-install.
Writes a private .img file, never a block device. Does not flash or reboot.
EOF
}

flake=""
output=""
wifi=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --flake|--output|--wifi-profile)
      [[ $# -ge 2 && -n "$2" ]] || die "$1 requires a value"
      case "$1" in
        --flake) flake=$2 ;;
        --output) output=$2 ;;
        --wifi-profile) wifi=$2 ;;
      esac
      shift 2
      ;;
    --help|-h) usage; exit 0 ;;
    *) die "Unknown argument: $1" ;;
  esac
done
[[ -n "$flake" && -n "$output" && "$flake" == *#* ]] || { usage >&2; exit 2; }
host=${flake##*#}
[[ "$host" =~ ^[a-zA-Z0-9][a-zA-Z0-9_-]*$ ]] || die "Use a host name after #"
checkout=${flake%#*}
checkout=$(realpath -- "${checkout:-.}")
[[ -f "$checkout/flake.nix" && -d "$checkout/hosts/$host" ]] || die "Use a local flake checkout with hosts/$host"
git -C "$checkout" diff --cached --quiet || die "Keep unrelated changes unstaged before enrollment"

# Reject unsafe destinations before any GitHub or enrollment side effects.
output=$(realpath -m -- "$output")
case "$output/" in
  "$checkout/"*|/nix/store/*) die "The private image must be outside the checkout and Nix store" ;;
esac
[[ ! -e "$output" && ! -L "$output" && ! -e "$output.sha256" && ! -L "$output.sha256" ]] || die "Output or checksum already exists"
[[ -d "$(dirname -- "$output")" && -w "$(dirname -- "$output")" ]] || die "Output directory must exist and be writable"
if [[ -n "$wifi" ]]; then
  wifi=$(realpath -- "$wifi")
  [[ -f "$wifi" && -r "$wifi" ]] || die "Wi-Fi profile is not readable"
  case "$wifi/" in
    "$checkout/"*|/nix/store/*) die "Wi-Fi credentials must stay outside the checkout and Nix store" ;;
  esac
fi
scratch=$(realpath -- "${TMPDIR:-/tmp}")
case "$scratch/" in
  "$checkout/"*|/nix/store/*) die "TMPDIR must be outside the checkout and Nix store" ;;
esac
cd "$checkout"
staging=$(mktemp -d "$scratch/nixos-sd-image-$host.XXXXXX")
image=""
rootfs=""
cleanup() {
  rm -rf -- "$staging"
  [[ -z "$image" ]] || rm -f -- "$image"
  [[ -z "$rootfs" ]] || rm -f -- "$rootfs"
}
trap cleanup EXIT
trap 'exit 130' INT
trap 'exit 143' TERM
config="$checkout#nixosConfigurations.$host.config"

# Check that this host really exposes a supported SD layout before enrolling it.
nix eval --no-update-lock-file --json "$config" --apply 'c: {
  hostName = c.networking.hostName;
  firmwareLabel = c.sdImage.firmwarePartitionName;
  rootLabel = c.sdImage.rootVolumeLabel;
  rootFsType = c.fileSystems."/".fsType;
  imageDefined = c.system.build ? sdImage;
}' >"$staging/metadata.json"
python3 - "$staging/metadata.json" "$host" <<'PY'
import json, sys
c = json.load(open(sys.argv[1]))
if not (c['hostName'] == sys.argv[2] and c['rootFsType'] == 'ext4'
        and c['imageDefined'] and c['rootLabel'] and c['firmwareLabel']):
    raise SystemExit('Expected a matching host with an ext4 SD-image layout.')
PY

nixos-remote-install --flake "$checkout#$host" --prepare-only "$staging/extra"
user_key_path=$(nix eval --no-update-lock-file --raw "$config.age.secrets.user-ssh-key.path")
[[ "$user_key_path" == /home/potter/.ssh/id_ed25519 ]] || die "The image must deploy Potter's user key through agenix"

echo "==> build ${host} SD image"
build=$(nix build --no-update-lock-file --no-link --print-out-paths "$config.system.build.sdImage")
shopt -s nullglob
images=("$build"/sd-image/*.img "$build"/sd-image/*.img.zst)
[[ ${#images[@]} -eq 1 ]] || die "Expected exactly one SD image in the build output"
image=$(mktemp "$(dirname -- "$output")/.$host-image.XXXXXX")
rootfs=$(mktemp "$(dirname -- "$output")/.$host-root.XXXXXX")
if [[ "${images[0]}" == *.zst ]]; then
  zstd --decompress --stdout -- "${images[0]}" >"$image"
else
  cp --reflink=auto --sparse=always -- "${images[0]}" "$image"
fi

echo "==> provision host identity outside the Nix store"
# Operate only on regular files. Extracting the root partition avoids loop
# devices, mounts, elevated privileges, and dependence on the builder's CPU.
sfdisk --json "$image" >"$staging/partitions.json"
python3 - "$image" "$rootfs" "$staging" "$wifi" <<'PY'
import json, os, pathlib, re, subprocess, sys
image, rootfs, staging = map(pathlib.Path, sys.argv[1:4])
wifi = sys.argv[4]
meta = json.loads((staging / 'metadata.json').read_text())
table = json.loads((staging / 'partitions.json').read_text())['partitiontable']
parts = table['partitions']
if table['label'] != 'dos' or len(parts) != 2:
    raise SystemExit('Expected the generic SD image DOS table with two partitions.')
fat, root = parts
if fat['type'].lower() not in ('b', 'c', '0b', '0c', 'e', '0e') or root['type'].lower() != '83':
    raise SystemExit('Expected FAT firmware followed by Linux root.')
sector = table.get('sectorsize', 512)
offset, length = root['start'] * sector, root['size'] * sector
fat_offset = fat['start'] * sector
if not (sector == 512 and 0 < fat_offset < offset and fat['size'] > 0
        and fat_offset + fat['size'] * sector <= offset
        and length > 0 and offset + length <= image.stat().st_size):
    raise SystemExit('Invalid or overlapping SD partition boundaries.')

def run(*args):
    return subprocess.run(args, check=True, capture_output=True, text=True)

run('dd', f'if={image}', f'of={rootfs}', 'bs=4M', f'skip={offset}', f'count={length}',
    'iflag=skip_bytes,count_bytes', 'conv=sparse', 'status=none')
if run('blkid', '-p', '-s', 'TYPE', '-o', 'value', str(rootfs)).stdout.strip() != 'ext4':
    raise SystemExit('Root partition is not ext4.')
if run('blkid', '-p', '-s', 'LABEL', '-o', 'value', str(rootfs)).stdout.strip() != meta['rootLabel']:
    raise SystemExit('Root filesystem label does not match the host.')

keys = staging / 'extra/etc/ssh'
commands = ['mkdir /etc', 'mkdir /etc/ssh']
for name, mode in [('ssh_host_ed25519_key', '0100600'), ('ssh_host_ed25519_key.pub', '0100644')]:
    commands += [f'rm /etc/ssh/{name}', f'write {name} /etc/ssh/{name}',
                 f'set_inode_field /etc/ssh/{name} mode {mode}',
                 f'set_inode_field /etc/ssh/{name} uid 0', f'set_inode_field /etc/ssh/{name} gid 0']
batch = keys / 'debugfs.commands'
batch.write_text('\n'.join(commands) + '\n')
subprocess.run(['debugfs', '-w', '-f', str(batch), str(rootfs)], cwd=keys,
               check=True, capture_output=True)
# debugfs does not reliably return nonzero for a failed batch command.
for name, mode in [('ssh_host_ed25519_key', '0600'), ('ssh_host_ed25519_key.pub', '0644')]:
    dump = staging / ('verified-' + name)
    subprocess.run(['debugfs', '-R', f'dump /etc/ssh/{name} {dump.name}', str(rootfs)],
                   cwd=staging, check=True, capture_output=True)
    if not dump.is_file() or dump.read_bytes() != (keys / name).read_bytes():
        raise SystemExit('Host identity was not written correctly.')
    stat = run('debugfs', '-R', f'stat /etc/ssh/{name}', str(rootfs)).stdout
    if not re.search(r'Mode:\s+' + mode + r'\b', stat) or not re.search(r'User:\s+0\s+Group:\s+0\b', stat):
        raise SystemExit('Host identity permissions are incorrect.')
run('e2fsck', '-f', '-n', str(rootfs))
run('dd', f'if={rootfs}', f'of={image}', 'bs=4M', f'seek={offset}',
    'oflag=seek_bytes', 'conv=notrunc', 'status=none')
if wifi:
    target = f'{image}@@{fat_offset}'
    run('mcopy', '-o', '-i', target, wifi, '::custard-wifi.nmconnection')
    # Verify bytes without printing credentials or depending on text encoding.
    data = subprocess.run(['mtype', '-i', target, '::custard-wifi.nmconnection'],
                          check=True, capture_output=True).stdout
    if data != pathlib.Path(wifi).read_bytes():
        raise SystemExit('Wi-Fi profile verification failed.')
with image.open('rb') as file:
    os.fsync(file.fileno())
PY

mv --no-clobber -- "$image" "$output"
[[ ! -e "$image" ]] || die "Output appeared during the build; refusing to overwrite it"
image=""
(
  cd "$(dirname -- "$output")"
  set -o noclobber
  sha256sum -- "$(basename -- "$output")" >"$(basename -- "$output").sha256"
)
sync -f "$output"
echo "==> ready to flash: $output"
echo "    This image contains ${host}'s private host identity. Keep it private and use it only for that device."
