# Host helpers for this flake.
#
# Add a NixOS host:
#   1. Create hosts/<name>/{default.nix, hardware-configuration.nix, home.nix}
#      Headless + nixos-anywhere: also add disk.nix (disko) and register disko.nixosModules.disko.
#   2. Import the nixos/home profiles you need (common + tailscale for headless; no desktop).
#   3. SSH: GitHub .keys via modules/nixos/ssh-github.nix (agenix for private keys).
#      Installer (roundabout): nixos-remote-install --flake .#<name> root@<iso>
#      (keygen, GitHub POST, agenix, git push, then nixos-anywhere).
#   4. Register in flake.nix:
#        nixosConfigurations.<name> = mkNixosHost {
#          system = "x86_64-linux";
#          modules = [ ./hosts/<name> ];  # plus flake-input nixos modules as needed
#          homeModules = [ ./home/potter ./hosts/<name>/home.nix ];
#          extraOverlays = [ ];  # e.g. cachyos
#        };
#
# Add a non-NixOS / HM-only host (Ubuntu, Fedora+Nix, etc.):
#   homeConfigurations."potter@<name>" = mkHomeConfiguration {
#     system = "x86_64-linux";
#     modules = [ ./home/potter ./hosts/<name>/home.nix ];
#   };
#   Do NOT import modules/nixos/*.
#
# Add a nix-darwin host (macOS):
#   1. darwin + nixpkgs-darwin + nixpkgs-unstable + home-manager-darwin + nix-homebrew
#      + determinate (already in flake.nix). mkDarwinHost: x86_64-darwin ->
#      nixpkgs-26.05-darwin; other Darwin -> nixpkgs-unstable. NixOS always uses
#      nixos-unstable. Determinate owns Nix on Darwin (nix.enable = false).
#   2. hosts/<name>/{default.nix, home.nix} — import modules/darwin/*, not modules/nixos/*.
#   3. Home: zsh.nix + ssh.nix from modules/home (not common.nix / desktop / niri).
#      Incoming SSH: modules/darwin/ssh.nix (GitHub snapshot authorized_keys + Remote Login).
#      User private key: agenix secrets/ssh/<name>/id_ed25519.age when that file exists.
#   4. Register:
#        darwinConfigurations.<name> = mkDarwinHost {
#          system = "x86_64-darwin";  # or aarch64-darwin
#          modules = [ ./hosts/<name> ];
#          homeModules = [ ./hosts/<name>/home.nix ];
#        };
#   Do not apply overlays.default (Linux-only packages / hardcoded x86_64-linux).
{ self, inputs }:

let
  inherit (inputs) nixpkgs home-manager darwin home-manager-darwin;
  inherit (nixpkgs.lib) hasPrefix hasSuffix;

  # NixOS / Linux HM: always github:NixOS/nixpkgs/nixos-unstable — not nixpkgs-unstable.
  nixosNixpkgs = inputs.nixpkgs;

  # Darwin pkgs: Intel is gone from unstable, so x86_64 stays on 26.05.
  darwinNixpkgsFor =
    system:
    if !hasSuffix "-darwin" system then
      throw "mkDarwinHost: '${system}' is not a darwin system"
    else if hasPrefix "x86_64" system then
      inputs.nixpkgs-darwin
    else
      inputs.nixpkgs-unstable;
in
{
  mkNixosHost =
    {
      system,
      modules,
      homeModules,
      homeUser ? "potter",
      extraOverlays ? [ ],
      specialArgs ? {
        inherit self inputs;
      },
    }:
    nixosNixpkgs.lib.nixosSystem {
      inherit system specialArgs;
      modules = modules ++ [
        { nixpkgs.overlays = [ self.overlays.default ] ++ extraOverlays; }
        inputs.agenix.nixosModules.default
        home-manager.nixosModules.home-manager
        {
          home-manager.useGlobalPkgs = true;
          home-manager.useUserPackages = true;
          home-manager.backupFileExtension = "backup";
          home-manager.overwriteBackup = true;
          home-manager.extraSpecialArgs = { inherit inputs; };
          home-manager.users.${homeUser} = {
            imports = homeModules;
          };
        }
      ];
    };

  mkHomeConfiguration =
    {
      system,
      modules,
      extraOverlays ? [ ],
    }:
    home-manager.lib.homeManagerConfiguration {
      pkgs = import nixosNixpkgs {
        inherit system;
        config = {
          allowUnfree = true;
        };
        overlays = [ self.overlays.default ] ++ extraOverlays;
      };
      extraSpecialArgs = { inherit inputs; };
      inherit modules;
    };

  mkDarwinHost =
    {
      system,
      modules,
      homeModules,
      homeUser ? "potter",
      extraOverlays ? [ ],
      specialArgs ? {
        inherit self inputs;
      },
    }:
    darwin.lib.darwinSystem {
      inherit system specialArgs;
      pkgs = import (darwinNixpkgsFor system) {
        inherit system;
        config = {
          allowUnfree = true;
          # 26.05 still builds Intel Macs but warns; silence that on this flake.
          allowDeprecatedx86_64Darwin = hasPrefix "x86_64" system;
        };
        overlays = extraOverlays;
      };
      modules = modules ++ [
        inputs.determinate.darwinModules.default
        {
          # Determinate owns /etc/nix/nix.conf; do not let nix-darwin replace it.
          determinateNix.enable = true;
        }
        inputs.agenix.darwinModules.default
        home-manager-darwin.darwinModules.home-manager
        {
          home-manager.useGlobalPkgs = true;
          home-manager.useUserPackages = true;
          home-manager.backupFileExtension = "backup";
          home-manager.overwriteBackup = true;
          home-manager.extraSpecialArgs = { inherit inputs; };
          home-manager.users.${homeUser} = {
            imports = homeModules;
          };
        }
      ];
    };
}
