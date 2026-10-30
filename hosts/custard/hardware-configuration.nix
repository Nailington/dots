# Raspberry Pi 5 Model B, aarch64, microSD boot. Board quirks/kernel come from
# nixos-hardware.nixosModules.raspberry-pi-5, registered in flake.nix.
{ lib, modulesPath, ... }:

{
  # Also expose system.build.sdImage for a spare-card installation/recovery.
  imports = [ (modulesPath + "/installer/sd-card/sd-image-aarch64.nix") ];

  nixpkgs.hostPlatform = lib.mkDefault "aarch64-linux";
  hardware.raspberry-pi.firmware = {
    enable = true;
    uboot.enable = true;
  };

  sdImage = {
    firmwareSize = 1024;
    firmwarePartitionName = "CUSTARD_FW";
    rootVolumeLabel = "CUSTARD";
  };

  # sd-image-aarch64 mounts the FAT partition with noauto/nofail by default.
  # It must be mounted at switch time so nixos-hardware can update boot firmware.
  fileSystems."/boot/firmware".options = lib.mkForce [ "umask=0077" ];

  # The Samsung T7 USB data disk is deliberately outside the install layout.
}
