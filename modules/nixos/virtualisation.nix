{
  # Docker CLI + daemon; daemon not started at boot (socket activation may still start it).
  virtualisation.docker = {
    enable = true;
    enableOnBoot = false;
  };
  virtualisation.libvirtd.enable = true;
}
