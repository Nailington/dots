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
# Add nix-darwin later:
#   1. Add input: darwin.url = "github:LnL7/nix-darwin"; darwin.inputs.nixpkgs.follows = "nixpkgs";
#   2. Create modules/darwin/common.nix and hosts/<mac>/default.nix
#   3. Mirror mkNixosHost as mkDarwinHost (darwin.lib.darwinSystem + HM darwin module).
#   4. Import only portable modules/home/* (common, dev, …) — not hyprland, not osx-kvm.
#      osx-kvm is KVM guest tooling on Linux NixOS, not for Mac hosts.
{ self, inputs }:

let
  inherit (inputs) nixpkgs home-manager;
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

  # Stub for later — do not call until nix-darwin is an input:
  # mkDarwinHost = { system, modules, homeModules, ... }: ...
}
