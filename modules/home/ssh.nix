{ pkgs, lib, ... }:

{
  # Shared SSH client — Linux common.nix and Darwin home. No Linux-only packages.
  programs.ssh = {
    enable = true;
    extraOptionOverrides = lib.mkIf pkgs.stdenv.hostPlatform.isDarwin {
      AddKeysToAgent = "yes";
      UseKeychain = "yes";
    };
    matchBlocks = {
      "hammerpot" = {
        hostname = "hammerpot-server";
        identityFile = "~/.ssh/ssh-key-2024-11-04.key";
        user = "ubuntu";
      };
      "crack" = {
        identityFile = "~/.ssh/oracle.key";
        user = "ubuntu";
      };
      "abacab" = {
        hostname = "abacab";
        identityFile = "~/.ssh/id_ed25519";
        user = "potter";
      };
      "ewbtciast" = {
        hostname = "ewbtciast";
        identityFile = "~/.ssh/id_ed25519";
        user = "potter";
      };
      "osx-kvm" = {
        hostname = "nixos";
        port = 10022;
        user = "potter";
      };
      "geoimac" = {
        hostname = "192.168.6.36";
        user = "gsiii";
      };
      "potterimac" = {
        hostname = "192.168.6.36";
        user = "potter";
      };
    };
  };
}
