# Potter's systems

This repository is the Nix flake for three machines used by `potter`. Shared configuration lives in `modules/`, and machine-specific configuration lives in `hosts/<name>/`.

The hardware details below come from fastfetch output supplied on 2026-09-25, plus a local memory check on `roundabout`. OS, kernel, and desktop versions describe that snapshot and will change with updates. Disk sizes are reported filesystem capacities, not manufacturer drive sizes.

## `roundabout` — daily-driver laptop

A 16-inch Acer Nitro ANV16-42 running NixOS. It is the desktop, gaming, development, and virtualization machine. Its current desktop is niri on Wayland; the flake also configures NVIDIA PRIME and a CachyOS kernel.

- **CPU:** AMD Ryzen 5 240, 12 logical processors.
- **Graphics:** NVIDIA GeForce RTX 5050 Max-Q / Mobile and integrated AMD Radeon 760M.
- **Memory:** 14 GiB usable, as reported by `free`.
- **Display:** Built-in 1920 × 1200, 60 Hz.
- **Storage:** 1.79 TiB ext4 root filesystem.
- **Software at snapshot:** NixOS 26.11, Linux 7.2.4-cachyos, niri 26.04.
- **Configuration:** [`hosts/roundabout/`](hosts/roundabout/).

## `abacab` — headless server

A NixOS VPS running under KVM/QEMU. It hosts web services through Nginx, uses a separate data volume at `/mnt/storage`, and has no desktop environment.

- **CPU:** AMD EPYC 7443, 6 virtual CPUs allocated.
- **Graphics:** QEMU virtual video controller.
- **Memory:** 47.05 GiB available to the guest.
- **Storage:** 244.52 GiB ext4 root filesystem and 915.31 GiB ext4 data filesystem mounted at `/mnt/storage`.
- **Software at snapshot:** NixOS 26.11, Linux 6.18.44.
- **Configuration:** [`hosts/abacab/`](hosts/abacab/).

## `ewbtciast` — Intel iMac

A 2017, 21-inch iMac (iMac18,1) running macOS with OpenCore Legacy Patcher. Its Nix configuration uses nix-darwin and Home Manager.

- **CPU:** Intel Core i5-7360U at 2.30 GHz, 4 logical processors.
- **Graphics:** Integrated Intel Iris Plus Graphics 640.
- **Memory:** 8 GiB.
- **Display:** Built-in 1920 × 1080, 60 Hz.
- **Storage:** 931.32 GiB APFS root filesystem.
- **Software at snapshot:** macOS Sequoia 15.7.9, Darwin 24.6.0.
- **Configuration:** [`hosts/ewbtciast/`](hosts/ewbtciast/).

For more about what each host runs and why, see [`docs/agents/hosts.md`](docs/agents/hosts.md).
