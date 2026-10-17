{
  # Docker CLI + daemon; daemon not started at boot (socket activation may still start it).
  virtualisation.docker = {
    enable = true;
    enableOnBoot = false;
  };
  virtualisation.libvirtd.enable = true;
  # VMware needs host configuration, kernel modules, and services as well as the GUI.
  virtualisation.vmware.host.enable = true;
  # Reserve CPU virtualisation only while KVM VMs run, allowing VMware to use it too.
  boot.kernelParams = [ "kvm.enable_virt_at_load=0" ];
}
