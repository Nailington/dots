# Single-disk wipe: EFI + ext4 root. Used by nixos-anywhere via disko.
#
# BEFORE install: set `device` to the target disk (prefer stable by-id):
#   ls -l /dev/disk/by-id/
# Example: "/dev/disk/by-id/nvme-Samsung_..."
{
  disko.devices = {
    disk.main = {
      type = "disk";
      device = "/dev/sda"; # CHANGE ME before nixos-anywhere
      content = {
        type = "gpt";
        partitions = {
          ESP = {
            size = "512M";
            type = "EF00";
            content = {
              type = "filesystem";
              format = "vfat";
              mountpoint = "/boot";
              mountOptions = [ "umask=0077" ];
            };
          };
          root = {
            size = "100%";
            content = {
              type = "filesystem";
              format = "ext4";
              mountpoint = "/";
            };
          };
        };
      };
    };
  };
}
