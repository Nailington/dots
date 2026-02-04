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
  };

  outputs = { self, nixpkgs, home-manager, rofi-themes, ... }@inputs:
  let
    system = "x86_64-linux";
    
    pkgs = import nixpkgs {
      inherit system;
      config.allowUnfree = true;
      overlays = [ self.overlays.default ];
    };
  in
  {
    # Custom packages overlay
    overlays.default = final: prev: {
      rofi-themes-collection = final.callPackage ./pkgs/rofi-themes {
        rofiThemesSrc = rofi-themes;
      };
    };

    nixosConfigurations.nixos = nixpkgs.lib.nixosSystem {
      inherit system;
      
      specialArgs = { inherit inputs; };
      
      modules = [
        ./hosts/nixos/configuration.nix
        
        # Apply our overlay to the system
        { nixpkgs.overlays = [ self.overlays.default ]; }
        
        home-manager.nixosModules.home-manager
        {
          home-manager.useGlobalPkgs = true;
          home-manager.useUserPackages = true;
          home-manager.users.potter = import ./home/potter.nix;
          home-manager.extraSpecialArgs = { inherit inputs; };
        }
      ];
    };
  };
}
