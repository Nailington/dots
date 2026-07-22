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

    flameshot.url = "github:flameshot-org/flameshot";

    nix-flatpak.url = "github:gmodena/nix-flatpak/?ref=latest";

    rofi-tools.url = "github:szaffarano/rofi-tools";

    # CachyOS-patched kernel (do not override nixpkgs on this input)
    nix-cachyos-kernel.url = "github:xddxdd/nix-cachyos-kernel/release";

    # renatus777rr/OSX-KVM-updated — scripts + OpenCore + OVMF (devShell flake ignored via flake = false)
    osx-kvm = {
      url = "github:renatus777rr/OSX-KVM-updated?submodules=1";
      flake = false;
    };

    helium = {
      url = "github:Nytelife26/nixpkgs/helium/init";
    };

    rockpload = {
      url = "github:LEX0RE/rockpload";
    };
  };

  outputs =
    {
      self,
      nixpkgs,
      home-manager,
      rofi-themes,
      nix-index,
      nix-flatpak,
      rofi-tools,
      nix-cachyos-kernel,
      flameshot,
      helium,
      rockpload,
      ...
    }@inputs:
    let
      system = "x86_64-linux";

      inherit (import ./lib/hosts.nix { inherit self inputs; })
        mkNixosHost
        mkHomeConfiguration
        ;

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

        nix-index = nix-index.packages.${system}.default;

        # Interim until nixpkgs PR merges — github:Nytelife26/nixpkgs/helium/init
        helium = helium.legacyPackages.${system}.helium;

        # nixpkgs#426717 — koffydrop: doCheck off only for i686, keeps x86_64 openldap cached
        openldap = prev.openldap.overrideAttrs (_: {
          doCheck = !prev.stdenv.hostPlatform.isi686;
        });
      };

      nixosConfigurations.roundabout = mkNixosHost {
        inherit system;
        modules = [
          ./hosts/roundabout
          nix-flatpak.nixosModules.nix-flatpak
          rockpload.nixosModules.default
        ];
        homeModules = [
          ./home/potter
          ./hosts/roundabout/home.nix
        ];
        extraOverlays = [ nix-cachyos-kernel.overlays.default ];
      };

      # Scaffold for non-NixOS / HM-only machines. roundabout itself still uses
      # HM-as-NixOS-module via mkNixosHost above; this output is the pattern for
      # future Ubuntu/Fedora+Nix boxes (same home modules, no NixOS profiles).
      homeConfigurations."potter@roundabout" = mkHomeConfiguration {
        inherit system;
        modules = [
          ./home/potter
          ./hosts/roundabout/home.nix
        ];
      };
    };
}
