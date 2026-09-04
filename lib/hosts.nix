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
#   1. darwin + nixpkgs-darwin + home-manager-darwin + nix-homebrew inputs (already in flake.nix).
#      Intel (x86_64-darwin) must stay on nixpkgs-26.05-darwin; 26.11 dropped that platform.
#   2. hosts/<name>/{default.nix, home.nix} — import modules/darwin/*, not modules/nixos/*.
#   3. Home: modules/home/zsh.nix only from the Linux home tree (not common.nix / desktop / niri).
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
    nixpkgs.lib.nixosSystem {
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
      pkgs = import nixpkgs {
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
      modules = modules ++ [
        {
          nixpkgs.hostPlatform = system;
          nixpkgs.config.allowUnfree = true;
          # 26.05 still builds Intel Macs but warns; silence that on this flake.
          nixpkgs.config.allowDeprecatedx86_64Darwin = true;
          nixpkgs.overlays = extraOverlays;
        }
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
