# Minimal / generic hardware stub for first nixos-anywhere install.
# Prefer regenerating on the target (or via nixos-anywhere):
#   nixos-anywhere --flake .#abacab --generate-hardware-config nixos-generate-config ./hosts/abacab/hardware-configuration.nix ...
{ lib, modulesPath, ... }:

{
  imports = [ (modulesPath + "/installer/scan/not-detected.nix") ];

  boot.initrd.availableKernelModules = [
    "xhci_pci"
    "ahci"
    "nvme"
    "usbhid"
    "usb_storage"
    "sd_mod"
    "sr_mod"
    "virtio_pci"
    "virtio_scsi"
    "virtio_blk"
    "virtio_net"
  ];
  boot.initrd.kernelModules = [ ];
  boot.kernelModules = [ "kvm-intel" "kvm-amd" ];
  boot.extraModulePackages = [ ];

  # Root/ESP come from disko (disk.nix) — do not declare fileSystems here.

  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
}
