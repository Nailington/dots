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
Before replacing EndeavourOS, test a spare card with HDMI, Ethernet/Wi-Fi,
Bluetooth, audio, acceleration, DMS login/lock, file-manager mounts, screenshots,
and the apps you use. With 4 GB RAM, start with a single 1080p display and assess
responsiveness. Zram is enabled and native Nix builds are limited to one job/two
cores. A kernel or large desktop package may need a substantial local build if
its exact derivation is absent from binary caches.

If niri starts to a black screen, check its
[ARM/render-device guidance](https://niri-wm.github.io/niri/Getting-Started.html)
and `/dev/dri/` before adding a `render-drm-device` override. No device number is
hardcoded here. The existing WezTerm window rule is reused. Hardware video decode
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
Dolphin, Thunar, Inkscape, Prism Launcher, Kitty, WezTerm, mpv, Meld, Xed,
Flameshot, the partition/file/archive tools, and familiar CLI/development tools.
The shared common, KDE, dev-tui and NixOS desktop modules already cover many of
these; custard selects individual apps from the mixed gaming/creative/desktop
profiles instead of bringing in Steam, VMware, CUDA, Chrome, or local x86 binaries.

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

## Safe transition on a spare microSD

Do not run `nh os switch` on EndeavourOS to convert the current installation.
Keep the original card intact as the recovery path. Back up home/app data,
SSH identities, browser profiles, Prism instances, JDownloader data, and any
service data before writing installation media. The NTFS T7 can hold archive
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

The output contains an `.img.zst` to flash to the **spare microSD** using an
image-writing tool. Verify the destination: writing an image erases that card.
No flashing or installation has been performed by this change. A normal
x86_64 roundabout builder cannot build an ARM closure just by naming custard;
configure a suitable builder first. The temporary validation CLI used in this
session is not a system Nix installation or a deployment prerequisite installed
by the flake.

Boot the spare card with Ethernet connected. From an existing trusted host such
as roundabout, use a GitHub-authorized SSH identity to connect as root to its LAN
IP, then set the local desktop password:

```sh
ssh root@<custard-lan-ip>
passwd potter
```

There is no default local password. Root SSH uses keys; Potter's wheel sudo will
ask for the password you set. The known public-key snapshot permits first login
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
spare-card image route above avoids those bootstrap assumptions.

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
