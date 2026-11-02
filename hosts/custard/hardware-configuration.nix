# Raspberry Pi 5 Model B, aarch64, microSD boot. Board quirks/kernel come from
# nixos-raspberrypi's Pi 5 modules, registered in flake.nix.
{ lib, pkgs, nixos-raspberrypi, ... }:

let
  vendorPackages = nixos-raspberrypi.packages.${pkgs.stdenv.hostPlatform.system};
in
{
  nixpkgs.hostPlatform = lib.mkDefault "aarch64-linux";

  # The upstream image intends to disable the generic all-hardware profile.
  # Use the canonical module name (its current absolute path lacks a slash).
  disabledModules = [ "profiles/all-hardware.nix" ];

  # Direct firmware boot with NixOS generations; no Pi 5 U-Boot dependency.
  boot.loader.raspberry-pi.bootloader = "kernel";
  # Supply metadata expected by unstable's boot/device-tree modules. Passthru
  # does not change the cached kernel's build inputs or output paths.
  boot.kernelPackages = vendorPackages.linuxPackages_rpi5.extend (_final: prev: {
    kernel = prev.kernel.override (args: {
      extraPassthru = (args.extraPassthru or { }) // {
        target = "Image";
        buildDTBs = true;
      };
    });
  });
  # Keep the complete DTB tree, including overlays used by config.txt.
  hardware.deviceTree.enable = true;

  # The board module installs this vendor utility; unstable no longer exports it.
  nixpkgs.overlays = [
    (_final: _prev: { raspberrypi-utils = vendorPackages.raspberrypi-utils; })
  ];
  # Keep the vendor wireless firmware matched to the cached kernel/boot firmware.
  hardware.firmware = [ vendorPackages.raspberrypiWirelessFirmware ];

  # This image uses ext4; do not build unused out-of-tree ZFS kernel modules.
  boot.supportedFilesystems.zfs = lib.mkForce false;

  sdImage = {
    firmwareSize = 1024;
    firmwarePartitionName = "CUSTARD_FW";
    rootVolumeLabel = "CUSTARD";
  };

  # Keep firmware mounted for generation updates and first-boot Wi-Fi import.
  # The upstream image uses mkForce for automount; this host mounts it at boot.
  fileSystems."/boot/firmware".options = lib.mkOverride 40 [ "umask=0077" ];

  # The Samsung T7 USB data disk is deliberately outside the install layout.
}
