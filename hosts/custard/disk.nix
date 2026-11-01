# Optional destructive reinstall layout for nixos-remote-install/disko.
# Boot a Pi-compatible NixOS installer in RAM first; see docs/custard/README.md.
{ config, ... }:

{
  # The SD-image module owns the mounts, using filesystem labels so flashed
  # images and disko installs can both switch to this same host configuration.
  disko.enableConfig = false;
  disko.devices.disk.main = {
    type = "disk";
    device = "/dev/mmcblk0";
    content = {
      type = "gpt";
      partitions = {
        firmware = {
          size = "1G";
          type = "EF00";
          content = {
            type = "filesystem";
            format = "vfat";
            extraArgs = [ "-n" config.sdImage.firmwarePartitionName ];
            mountpoint = "/boot/firmware";
            mountOptions = [ "umask=0077" ];
          };
        };
        root = {
          size = "100%";
          content = {
            type = "filesystem";
            format = "ext4";
            extraArgs = [ "-L" config.sdImage.rootVolumeLabel ];
            mountpoint = "/";
          };
        };
      };
    };
  };
}
