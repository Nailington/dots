{ config, ... }:

{
  # DMS/matugen must be able to update the included theme files in the checkout.
  # Don't use programs.kitty — it writes kitty.conf and would clash with this tree.
  xdg.configFile."kitty".source = config.lib.file.mkOutOfStoreSymlink (
    "${config.potter.flakeDirectory}/modules/home/kitty/config"
  );
}
