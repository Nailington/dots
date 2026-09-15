{ ... }:

{
  # Don't use programs.kitty — it writes kitty.conf and would clash with this tree.
  xdg.configFile."kitty/kitty.conf".source = ./kitty.conf;
  xdg.configFile."kitty/dank-tabs.conf".source = ./dank-tabs.conf;
  xdg.configFile."kitty/dank-theme.conf".source = ./dank-theme.conf;
}
