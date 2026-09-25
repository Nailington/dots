# Hosts

User is `potter` on every host. Timezone is `America/New_York` via `modules/nixos/common.nix`.

## roundabout

Daily-driver laptop. NixOS, systemd-boot, CachyOS kernel (`linuxPackages-cachyos-latest` from `extraOverlays`), NVIDIA PRIME sync (AMD iGPU bus `PCI:101:0:0`, NVIDIA `PCI:1:0:0`). `stateVersion = "25.11"`. 32G swapfile, hibernation disabled. 

NixOS imports (`hosts/roundabout/default.nix`): `common`, `desktop`, `niri`, `gaming`, `networking-tailscale` (Tailscale **and** Mullvad), `virtualisation`, `nvidia-prime`, `linuwu-sense`, `damx`, `acer-sense`.

Hyprland and Plasma imports are commented in that file. Turn a session on by uncommenting its NixOS module and its home module together, and commenting niri out. Rules: [desktops.md](desktops.md).

Home imports: `common`, `desktop`, `niri`, `kitty`, `kde-apps`, `gaming`, `creative`, `spicetify`, `dev-tui`, `dev-gui`, `kde-craft`, `osx-kvm` (1920x1080). Hyprland home import is commented.

Hardware quirks that belong in the host file, not a shared module:

- `programs.linuwu-sense.force = "nitrov4"`, `programs.damx`, `programs.acer-sense`, `programs.coolercontrol`.
- potter groups: `wheel`, `networkmanager`, `docker`, `kvm`, `libvirtd`, `input`, `gamemode`, `linuwu_sense`, `fuse`.
- Flatpak: `org.vinegarhq.Sober`, `dev.khcrysalis.PlumeImpactor`. `services.rockpload`.
- Firewall TCP `45454`.
- DualSense touchpad ignored. BT5.1 mouse: udev symlink `/dev/bt51-mouse-kbd`, hwdb maps Calc/Mail scancodes to `btn_forward` / `btn_back`, and a user service `bt51-pointer-bridge` (evsieve) clones those onto a virtual pointer. The user must be in `input`.
- USB devices and USB disks are group `kvm` so osx-kvm can pass them through.
- NTFS: prefer ntfs-3g via udisks2. An "Acer" partition mount is commented out; leave it commented unless asked.
- `nixos-remote-install` is on the system path so this machine installs the others.
- Wi-Fi powersave off. `cfg80211` regdom `US`. Nested KVM (`kvm_amd nested=1`, `kvm ignore_msrs=1`).

`osx-kvm` launchers come from `modules/home/osx-kvm`. VM disk and firmware vars live in `~/VMs/osx-kvm`, not the Nix store. SSH to the guest is `ssh osx-kvm` (port 10022, user potter) from `modules/home/ssh.nix`.

## abacab

Headless VPS, installed with `nixos-remote-install`. Previously called 24fire; that old SSH key is retired.

It kexec'd from a BIOS environment, so systemd-boot could not boot it. Loader is GRUB on `/dev/sda` (`efiSupport` + `efiInstallAsRemovable`). Disk layout is `hosts/abacab/disk.nix` (disko: BIOS boot partition, ESP, ext4 root). Do not switch this host back to systemd-boot-only.

`/mnt/storage` (`39ed1bbb-0ebf-43fd-a02e-62187377b916`) is an existing data disk. It is mounted with `nofail` and is **outside** disko so a reinstall does not format it.

Networking overrides NetworkManager (`mkForce false`): systemd-networkd, static `45.92.216.66/23`, gateway `45.92.216.1`, DNS `1.1.1.1` / `1.0.0.1`. Mullvad egress is available through Tailscale exit nodes; there is no Mullvad daemon, desktop, or gaming stack.

Imports: `common`, `tailscale`, `nginx.nix`, `cron.nix`, disko. Home is `common` + `dev-tui` only.

Other facts:

- SSH: passwords off, root is `prohibit-password`. Login is GitHub keys via `ssh-github.nix`.
- `users.mutableUsers = true`. potter has a `hashedPassword` in `hosts/abacab/default.nix` so the first boot has a local password. `wheel` sudo still asks for it. Do not copy that hash into docs or chat.
- `programs.nix-ld` comes from `common.nix` (wanted so unpacked binaries work here too).
- Nginx vhosts are written inline in `hosts/abacab/nginx.nix` (ACME per hostname, email `acme@hammerpot.dev`). The comment about `../../nginx-conf/` is historical. The Ubuntu copies live in the unversioned parent folder `nixOSmoment/nginx-conf/` and are not imported.
- Minecraft Java for `ftc.hammerpot.dev` is TCP/UDP `40002`.
- Cron (`hosts/abacab/cron.nix`) runs `/mnt/storage/auto-rob` (`npm start`) on weekdays. Jobs source `/etc/profile` because cron's default PATH misses user profiles. Log: `/var/log/auto-rob.log`.
- qBittorrent runs headlessly. Downloads go to `/mnt/storage/torrents`, and the service requires that mount. Potter belongs to the `qbittorrent` group to manage downloaded files after a new login. Torrent sockets are bound to `tailscale0` and the systemd unit allows only `tailscale0` and loopback; its Web UI listens on `127.0.0.1:8080` and the firewall does not expose it. From the laptop, run `ssh -L 8080:127.0.0.1:8080 abacab` and open `http://127.0.0.1:8080`. On first launch, get the temporary admin password with `sudo journalctl -u qbittorrent -b` and set a permanent one in the Web UI.
- Select a licensed Mullvad exit node **on abacab** with `sudo tailscale set --exit-node=<mullvad-node>`; `tailscale exit-node list` lists available nodes. Check the route with `curl https://am.i.mullvad.net/connected` before starting torrents. This changes outbound routing for the whole server, including non-torrent services. If no exit node is selected, the torrent service's interface restriction prevents it from falling back to the public NIC.

## ewbtciast

2017 Intel iMac, OpenCore Legacy Patcher. Hostname spelling is intentional.

nix-darwin 26.05 + nixpkgs 26.05-darwin. Determinate Nix owns `/etc/nix/nix.conf`; nix-darwin must not replace it. See [darwin.md](darwin.md).

`system.stateVersion = 6`. `system.primaryUser = "potter"`. Home is `/Users/potter`, `home.stateVersion = "25.11"`. Home imports are `zsh.nix` and `ssh.nix` only. Homebrew is managed by nix-homebrew; casks/brews lists in `modules/darwin/common.nix` are currently empty (BlueBubbles was requested and may have been left empty — check the file before adding a cask).

Eval is kept light on purpose: `max-jobs = 2`, `eval-cores = 1`, `lazy-trees = true`, under `determinateNix.customSettings` (plain `nix.settings` is ignored while Determinate owns `nix.conf`).

Install and switch happen **on the Mac** with `nh darwin switch`. Linux is not the build machine for this configuration.

## SSH client names

`modules/home/ssh.nix` is shared. Match blocks:

| Alias | Target |
| --- | --- |
| `abacab` | `potter@abacab`, `~/.ssh/id_ed25519` |
| `ewbtciast` | `potter@ewbtciast`, `~/.ssh/id_ed25519` |
| `osx-kvm` | `potter@nixos:10022` |
| `hammerpot` | `ubuntu@hammerpot-server`, key `~/.ssh/ssh-key-2024-11-04.key` |
| `crack` | `ubuntu`, key `~/.ssh/oracle.key` |
| `geoimac` / `potterimac` | `192.168.6.36` as `gsiii` / `potter` |

`hammerpot` and `crack` are outside this flake. Their keys are not agenix identities.
