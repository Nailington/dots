# Cloud/QEMU guest: GPT + BIOS GRUB (EF02) + EFI fallback + ext4 root.
# The first install used systemd-boot only; kexec was not EFI, so the machine
# could not boot. GRUB is installed to the disk MBR and also as removable EFI.
{
  disko.devices = {
    disk.main = {
      type = "disk";
      device = "/dev/sda";
      content = {
        type = "gpt";
        partitions = {
          bios = {
            size = "1M";
            type = "EF02"; # BIOS boot (grub core.img on GPT)
          };
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
