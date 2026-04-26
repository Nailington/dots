{
  description = "Potter's NixOS Configuration";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Nailington's rofi themes (fork of adi1090x/rofi)
    rofi-themes = {
      url = "github:Nailington/rofi";
      flake = false;
    };

    nix-index = {
      url = "github:nix-community/nix-index";
    };

    nix-flatpak.url = "github:gmodena/nix-flatpak/?ref=latest";
    
    rofi-tools.url = "github:szaffarano/rofi-tools";

    # CachyOS-patched kernel (do not override nixpkgs on this input)
    nix-cachyos-kernel.url = "github:xddxdd/nix-cachyos-kernel/release";

  };

  outputs = { self, nixpkgs, home-manager, rofi-themes, nix-index, nix-flatpak, rofi-tools, nix-cachyos-kernel, ... }@inputs:
  let
    system = "x86_64-linux";
    
    pkgs = import nixpkgs {
      inherit system;
      config.allowUnfree = true;
      overlays = [ self.overlays.default ];
    };
  in
  {
    packages.${system} = {
      twitch-drops-miner = pkgs.twitch-drops-miner;
    };

    # Custom packages overlay
    overlays.default = final: prev: {
      rofi-themes-collection = final.callPackage ./pkgs/rofi-themes {
        rofiThemesSrc = rofi-themes;
      };
      posys-cursor-scalable = final.callPackage ./pkgs/posys-cursor-scalable { };
      seguiemj = final.callPackage ./pkgs/seguiemj { };
      hojas-de-plata = final.callPackage ./pkgs/hojas-de-plata { };
      althea = final.callPackage ./pkgs/althea { };
      singularcard = final.callPackage ./pkgs/singularcard { };
      cider = final.callPackage ./pkgs/cider { };
      twitch-drops-miner = final.callPackage ./pkgs/twitch-drops-miner { };
      # nix-index from flake (replaces nixpkgs version)
      nix-index = nix-index.packages.${system}.default;
    };

    nixosConfigurations.nixos = nixpkgs.lib.nixosSystem {
      inherit system;
      
      specialArgs = { inherit inputs; };
      
      modules = [
        ./hosts/nixos/configuration.nix
        ./modules/damx  # DAMX - Acer laptop control
        nix-flatpak.nixosModules.nix-flatpak
        
        # Our overlay + CachyOS kernel packages (pkgs.cachyosKernels.*)
        { nixpkgs.overlays = [ self.overlays.default nix-cachyos-kernel.overlays.default ]; }
        
        home-manager.nixosModules.home-manager
        {
          home-manager.useGlobalPkgs = true;
          home-manager.useUserPackages = true;
          home-manager.backupFileExtension = "backup";  # Backup conflicting files
          home-manager.users.potter = import ./home/potter.nix;
          home-manager.extraSpecialArgs = { inherit inputs; };
        }
      ];
    };
  };
}
