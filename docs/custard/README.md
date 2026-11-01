# custard: Raspberry Pi 5 migration

Captured on 2026-10-29 from this Raspberry Pi 5 Model B Rev 1.0, aarch64,
4 GB RAM, running EndeavourOS with a Raspberry Pi 6.18 kernel. The current
microSD is `/dev/mmcblk0` (about 461 GiB); `/dev/sda` is the separate Samsung
T7 NTFS data disk (about 932 GiB). Device names must be checked again at install.

## Configuration and support

`nixosConfigurations.custard` uses the existing `mkNixosHost` helper, integrated
Home Manager, agenix, GitHub SSH login, and native `aarch64-linux` packages.
Its dedicated `nixpkgs-aarch64` input is **nixos-unstable**, not `-small`.
Existing x86_64 and Darwin input revisions are unchanged. Linux package/tool
outputs now exist for both architectures; ARM does not export the local
x86-only application binaries.

The pinned upstream [Pi 5 profile](https://github.com/NixOS/nixos-hardware/blob/b6754c901c21478fd8450d62101e712b2a4f0d75/raspberry-pi/5/default.nix)
supplies the Raspberry Pi downstream kernel, BCM2712 device trees, RP1/PCIe
initrd support, and wireless firmware. The
[firmware module](https://github.com/NixOS/nixos-hardware/blob/b6754c901c21478fd8450d62101e712b2a4f0d75/raspberry-pi/README.md)
stages firmware and U-Boot on `/boot/firmware`; extlinux supplies NixOS generations.
Use microSD boot. Upstream documents limitations for USB/NVMe boot and USB
keyboard input in the Pi 5 U-Boot menu. Those do not imply USB is unavailable
after Linux boots. This configuration does not use the archived Pi 5 UEFI port.

Niri, DMS, the DMS greeter, Mesa, and Xwayland are available for ARM. The
[pinned DMS flake](https://github.com/AvengeMedia/DankMaterialShell/blob/8ce37501bd9c4dcbac04d1deb4e57d50f3e2c94f/flake.nix)
explicitly includes `aarch64-linux`. The same niri bindings, DMS fragments,
Kitty configuration, KWallet, GTK setup, and KDE apps are reused from roundabout.
Monitor modes are host-specific: custard autodetects displays, rather than
requesting roundabout's 4K/120 Hz output. Qtengine is built against the host's
Qt/KDE versions, avoiding plugins from the older x86 input pin.

This establishes configuration/package support, not a successful boot test.
The first boot after reflashing the current card must test HDMI, Wi-Fi,
Bluetooth, audio, acceleration, DMS login/lock, file-manager mounts, screenshots,
and the apps you use. Keep the T7 backup available during this migration.
With 4 GB RAM, start with a single 1080p display and assess
responsiveness. Zram is enabled and native Nix builds are limited to one job/two
cores. A kernel or large desktop package may need a substantial local build if
its exact derivation is absent from binary caches.

If niri starts to a black screen, check its
[ARM/render-device guidance](https://niri-wm.github.io/niri/Getting-Started.html)
and `/dev/dri/` before adding a `render-drm-device` override. No device number is
hardcoded here. The shared window rules are reused. Hardware video decode
and Minecraft/modpack performance still need testing on the real desktop.

## Application manifest

- [apps.tsv](apps.tsv): app/tool mapping, pinned ARM metadata, existing flake
  overlap, migration decision, and exceptions. A supported metadata entry means
  nixpkgs declares support; it is not a claim that the package was built or run.
- [pacman-explicit.txt](pacman-explicit.txt): every explicitly installed pacman
  package with its version, including fonts, drivers, and old desktop components.
- [pacman-foreign.txt](pacman-foreign.txt): all foreign/AUR packages with versions,
  including dependencies such as Electron runtimes.
- [desktop-launchers.tsv](desktop-launchers.tsv): installed visible application
  launchers and their package owners, including dependency-installed GUI tools.

All visible launcher owners are accounted for in the mapping, including the
EndeavourOS-specific welcome/update utilities that are not carried to NixOS.

The Flatpak CLI was not installed. `~/.local/bin` also contains standalone Codex
and T3 launchers; the flake supplies those through the shared dev-tui profile.
This is a package/launcher inventory, not an audit of arbitrary scripts, browser
extensions, npm/pip environments, or every downloaded application in the home.

The carried app base includes Firefox, Chromium, Vesktop, GitHub Desktop,
Dolphin, Ark, Inkscape, Prism Launcher, Kitty, mpv, Meld, Xed, Flameshot,
KDE Partition Manager, and familiar CLI/development tools.
The shared common, KDE, dev-tui and NixOS desktop modules already cover many of
these. Like roundabout, custard selects app profiles from `modules/home`:
`arm/desktop.nix`, `arm/dev-gui.nix`, `arm/creative.nix`, and `arm/gaming.nix`.
The ARM profiles own the package selections and reusable desktop defaults;
`hosts/custard/home.nix` contains imports and host-specific T3 settings. The x86
app profiles are kept separate, including their Steam, VMware, CUDA, Chrome,
and local x86 binary selections.

App defaults follow roundabout: Dolphin for files/removable volumes, Ark for
archives, Kitty for terminals, btop for monitoring, and DMS for audio/network
controls. Thunar and its extensions, Xarchiver, Xfce Terminal, WezTerm, Glances,
Pavucontrol, and the NetworkManager applet/editor remain commented out in
`arm/desktop.nix`. KDE Partition Manager and the re-enabled GParted are both
retained for partition editing. The rsync CLI is
kept instead of Grsync, and iperf3 instead of iperf2 (their protocols differ).
Wget, rsync, SSHFS, and Qt5 Breeze are supplied by the system package set.
Qt5ct and Qt6ct remain separate compatibility tools, as on roundabout. The original EndeavourOS
inventory is retained; `apps.tsv` records the reduced migration selection.

Exceptions:

- AnyDesk has an ARM nixpkgs package, but the vendor
  [requires Xorg for incoming sessions](https://support.anydesk.com/anydesk-for-linux-raspberry-pi).
  It is not enabled. Incoming AnyDesk control of the niri session will not work
  as a supported workflow. SSH/Tailscale remain available.
- The installed `chrome-remote-desktop-existing-session` AUR workflow has no
  direct package here and depends on the old desktop/session setup. It is not
  carried. A replacement remote desktop workflow needs a separate decision.
- JDownloader has no `jdownloader` attribute in this pinned nixpkgs. Keep its data
  for a later packaging/runtime choice; no unverified installer is added.
- The repo's Twitch Drops Miner package downloads an **x86_64 AppImage**. Nixpkgs
  has no matching package at this pin, so that binary is not installed on ARM.
  Keep its settings/tokens privately for a future source-based ARM package.
- Neofetch was removed upstream; Fastfetch is already in the common profile.
- i3, Picom, Polybar, Dunst, LightDM/SDDM, and the old lockers are replaced by
  niri/DMS/greetd. Rofi themes stay available in the repo but DMS is the launcher.
- The dozens of explicitly installed Nerd Font families are preserved in the
  raw inventory, not all installed again. The shared font set supplies Roboto
  Mono Nerd Font, Google Sans/Code/Flex, and emoji/fonts used by this desktop.
- JDK 21 is the shared default. Preserve Prism instance data and verify the Java
  version/native libraries needed by each instance rather than restoring Arch
  JDK paths. Dependency-owned JDK 17 and the rolling JDK are listed for review.

## Replace the current microSD installation

Do not run `nh os switch` on EndeavourOS to convert the current installation.
The intended install reuses the current microSD and erases EndeavourOS and all
data on that card. The T7 holds the verified full-home backup; it must remain
outside all formatting. Preserve the latest flake checkout and the first-boot
Wi-Fi file there too, since both changed after the full-home backup. Back up
any required data outside home separately before writing installation media.
The NTFS T7 can hold archive
files, but a plain copy to NTFS does not preserve all Unix metadata; use a
metadata-preserving archive or a filesystem that supports it. Keep private keys
and application tokens out of this repository and the Nix store.

On a machine with Nix and a native ARM builder (or explicitly configured remote
ARM builder/emulation), from this flake root:

```sh
nix build --no-update-lock-file --out-link result-custard-sd \
  '.#nixosConfigurations.custard.config.system.build.sdImage'
ls result-custard-sd/sd-image/
```

The output contains an `.img.zst`. Before erasing the running card, copy the
actual image file to the T7 (a `result-custard-sd` symlink alone will not survive
the wipe). Verify the copied file against the build output. Keep the separate
Wi-Fi provisioning file and current flake archive on the T7 as well.

For the image route, shut down the Pi, move this same card to another computer
with a card reader, and flash the image there. Verify the destination: writing
an image erases that card. Do not write an image over the Pi's mounted root
disk. A second microSD is not required. If the card must stay in the Pi, the
alternative is a Pi-compatible installer running entirely in RAM; that
bootstrap is not currently implemented or tested by this flake.

No flashing or installation has been performed. Roundabout and abacab enable
`boot.binfmt.emulatedSystems = [ "aarch64-linux" ]` in their host files. After
switching the updated configuration on the chosen builder, either x86_64 host
can build custard through QEMU user-mode emulation. Use the latest checkout,
including the uncommitted custard changes. Their own system/package platform
stays x86_64. The temporary validation CLI used in this
session is not a system Nix installation or a deployment prerequisite installed
by the flake.

Before first boot, provision Wi-Fi on the flashed card as described below.
Ethernet is optional. The image sets Potter's initial desktop/sudo password
from `initialHashedPassword` in the host configuration. The password was supplied
privately and hashed locally; its plaintext is not in the flake. Log into DMS
as `potter` with that password after first boot.

From an existing trusted host such as roundabout, a GitHub-authorized SSH
identity can also connect as root to administer the system or reset the password:

```sh
ssh root@<custard-lan-ip>
passwd potter
```

The initial password applies when the account is first created. It can be
changed later with `passwd`; rebuilds preserve subsequent password changes.
Root SSH uses keys; Potter's wheel sudo asks for the local password. The known
public-key snapshot permits SSH login
without having an agenix private-key backup on custard yet. Mounts use the
`CUSTARD`/`CUSTARD_FW` labels so a flashed card can switch to the regular host
configuration later. The SD image expands root on first boot. Do not leave two
cards with the same labels attached during that boot.

Restore user data deliberately. Home Manager owns the declared shell/Kitty/niri
files and uses `.backup` for existing files; do not replace its managed links
with a wholesale Arch `/etc` or home-config restore. The USB T7 remains outside
all formatting and can be mounted from Dolphin after boot.

Enroll the host using the existing
[SSH/agenix process](../agents/secrets-and-ssh.md). An `nh os switch` on custard
can snapshot its public keys; if it cannot yet decrypt the store, add the new
user public key to GitHub and run the usual switch on roundabout to refresh the
encrypted recipients. Bring that updated checkout back to custard. No secret
was created, re-encrypted, committed, or pushed during this onboarding edit.

After the host is installed and the checkout is in place, its usual command is:

```sh
nh os switch -- --flake .#custard
```

That wrapper runs recipient sync and may commit/push when keys change; keep
unrelated work unstaged. Tailscale needs authentication/state migration before
its old identity is usable. T3 is explicitly bound to loopback until a host-specific address and
corresponding Tailscale startup guard are configured.

## First-boot Wi-Fi

Custard can connect to Wi-Fi before anyone logs in. Its NetworkManager startup
wants `custard-wifi-bootstrap.service`, which runs first and imports an optional
`/boot/firmware/custard-wifi.nmconnection`. The service installs it as a
root-owned, mode-0600 profile under `/etc/NetworkManager/system-connections/`,
flushes that filesystem, then removes the copy from the firmware partition.
Subsequent boots use the saved profile. Without an import file, the service is
skipped and NetworkManager starts normally. NetworkManager's keyfile permissions
and format are documented [upstream](https://networkmanager.dev/docs/api/latest/nm-settings-keyfile.html).

On 2026-10-31, the running Pi's active WPA-PSK connection was used to prepare:

```text
/home/potter/.local/share/custard/first-boot/custard-wifi.nmconnection
```

This private file includes the current network's credentials, unrestricted
system autoconnect, and automatic IPv4/IPv6 configuration. It is not tied to an
interface name or a desktop login. It was validated with libnm and offline
nmcli without modifying the current connection. The file is outside Git and
the Nix store; no password is embedded in the flake or its SD-image output.
If the router credentials change, prepare an updated connection file before
installing. This file was created after the full-home backup.

The same-card migration snapshot on the T7 is
`extra_backup/custard-install-<timestamp>/custard-install.tar`. It contains
`dots/` (including Git metadata and uncommitted changes) and the separate
`custard-wifi.nmconnection`. The archive preserves Unix permissions that the T7
cannot enforce directly. It is not encrypted and contains the Wi-Fi password;
keep it private alongside the full-home backup.

After flashing, mount the **reflashed card's `CUSTARD_FW` FAT partition** on the
other computer. Extract the connection file to a private temporary directory
on that computer and copy it to the firmware partition's root. Replace the
source/destination mounts below with their actual paths; the destination is
not the T7 partition:

```sh
wifi_stage="$(mktemp -d)"
tar --extract \
  --file=/path/to/T7/extra_backup/custard-install-<timestamp>/custard-install.tar \
  --directory="$wifi_stage" custard-wifi.nmconnection
sudo install -m 0600 "$wifi_stage/custard-wifi.nmconnection" \
  /path/to/CUSTARD_FW/custard-wifi.nmconnection
sync
rm "$wifi_stage/custard-wifi.nmconnection"
rmdir "$wifi_stage"
```

Unmount the card from the other computer and boot it in the Pi. Custard should join the same
Wi-Fi network without Ethernet or a password prompt. Find its address through
the router's DHCP client list, then use the optional root SSH access above. Its
address may differ from EndeavourOS's address. Keep the provisioning file
private: it contains the Wi-Fi password. Reflashing requires copying it again.

This provisions the installed custard system. A future RAM-based remote
installer must also be given Wi-Fi support and credentials; adding this hook
alone does not configure that separate installer environment.

## Optional remote reinstall

`hosts/custard/disk.nix` describes a destructive GPT layout on `/dev/mmcblk0`:
1 GiB FAT firmware and the remaining space as ext4 root. It intentionally
excludes the T7. The SD-image module owns the runtime mounts; disko uses the
same filesystem labels and only supplies formatting/mount scripts.

The repo's `nixos-remote-install` wrapper can prepare SSH/agenix keys and run
nixos-anywhere, but **its default generic kexec installer is not a verified Pi 5
boot path**. Do not point the default command at this running EndeavourOS
system. A remote reinstall needs a Pi-compatible installer running from RAM or
other safe media, a suitable ARM build host, and a deliberate no-generic-kexec
installation plan. Do not format the mounted root card of a normal SD installer.
The wrapper also normally regenerates `hardware-configuration.nix`. For a Pi
reinstall, direct hardware generation to a separate file and review it: do not
overwrite the hand-maintained SD-image/firmware definitions in this host. The
image route above avoids those bootstrap assumptions, including when reusing
the current microSD after shutting the Pi down.

## Validation

See the recorded checks below. Package metadata is tied to the exact ARM
nixpkgs revision in `flake.lock`; it does not guarantee cache availability or
functional behavior on the Pi. Builds, activation, firmware boot, and desktop
runtime checks are distinct stages.

Recorded checks (2026-10-29, Nix 2.31.2 in a temporary isolated store):

- All changed/new Nix files parsed successfully.
- custard's NixOS toplevel, integrated Home Manager activation, SD image, disko
  script, and four maintenance-tool derivations evaluated with
  `--no-update-lock-file`. All NixOS assertions passed.
- Every directly selected system/Home Manager package has `aarch64-linux` as its
  build platform. App mappings were checked against vanilla ARM nixpkgs metadata
  at `31ecbaca1bdefa45dffc409f0250bd8039ea0010`; local-overlay exceptions are marked.
- Confirmed matching image/disko labels, microSD-only formatting target, enabled
  firmware updates/U-Boot, automatic monitor selection, and loopback-only T3.
- Existing input lock nodes were unchanged. roundabout/abacab still evaluate as
  x86_64 hosts. roundabout's monitor contents and Qtengine derivation are unchanged.
- The system realization dry-run completed successfully. The observed cache
  plan requires about 10 GiB of downloads / 25 GiB unpacked substitutes, plus
  local builds including the Pi kernel, Qtengine, patched GNOME settings daemon,
  and the pinned T3 nightly. Many other build steps are generated configuration;
  this is a build plan, not the final runtime closure size. Cache availability
  can change, and building the SD image also needs working space.
- No complete system/SD-image build or activation was performed. A small
  validation-time build hit `setgroups failed` in the unprivileged temporary Nix
  namespace; the actual image build needs a regular Nix installation/builder.
  Real boot, graphics, peripherals, and application behavior remain untested.

App-default cleanup (2026-10-30): Nix syntax and the integrated Home Manager
activation derivation evaluated successfully with `--no-update-lock-file`.
Package checks confirmed the selected defaults and removal of the alternate
GUIs. No rebuild or activation was performed.

ARM profile refactor (2026-10-30): all five changed/new Nix modules parsed, and
custard's NixOS toplevel and Home Manager activation derivations evaluated with
`--no-update-lock-file`. The before/after package selections (including GParted),
cursor, MIME defaults, T3 settings, and Flameshot configuration matched. No
build or activation was performed.

First-boot Wi-Fi (2026-10-31): the NixOS toplevel and SD-image derivations
evaluated with `--no-update-lock-file`; all NixOS assertions passed. Checked the
evaluated service's NetworkManager dependency, startup ordering, firmware mount,
and optional-file condition. Its shell script passed isolated first-import and
replacement checks for contents, permissions, persistence, and boot-copy removal.
The private connection file passed libnm and offline nmcli validation, with
autoconnect and no user restrictions. No image build, activation, or actual
first-boot association test was performed; the current Wi-Fi was not changed.
