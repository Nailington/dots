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

    disko = {
      url = "github:nix-community/disko";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    agenix = {
      url = "github:ryantm/agenix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nixos-anywhere = {
      url = "github:nix-community/nixos-anywhere";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Don't follow nixpkgs — Spicetify must track a Spotify version it can patch.
    # https://gerg-l.github.io/spicetify-nix/usage.html
    spicetify-nix.url = "github:Gerg-L/spicetify-nix";
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
      disko,
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
        config = {
          allowUnfree = true;
        };
        overlays = [ self.overlays.default ];
      };
    in
    {
      packages.${system} =
        let
          sync-age-recipients = pkgs.writeShellApplication {
            name = "sync-age-recipients";
            runtimeInputs = with pkgs; [
              age
              curl
              git
              nix
              python3
              findutils
              coreutils
            ];
            text = builtins.readFile ./scripts/sync-age-recipients.sh;
          };
          nixos-anywhere-unwrapped =
            inputs.nixos-anywhere.packages.${system}.nixos-anywhere
              or inputs.nixos-anywhere.packages.${system}.default;
        in
        {
          inherit sync-age-recipients;
          twitch-drops-miner = pkgs.twitch-drops-miner;
          auto-rob = pkgs.auto-rob;
          nixos-remote-install = pkgs.writeShellApplication {
            name = "nixos-remote-install";
            runtimeInputs = (with pkgs; [
              age
              openssh
              curl
              jq
              git
              nix
              coreutils
            ]) ++ [
              sync-age-recipients
              nixos-anywhere-unwrapped
            ];
            text = ''
              export NIXOS_ANYWHERE_REAL="${nixos-anywhere-unwrapped}/bin/nixos-anywhere"
              ${builtins.readFile ./scripts/nixos-remote-install.sh}
            '';
          };
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
        auto-rob = final.callPackage ./pkgs/auto-rob { };

        nix-index = nix-index.packages.${system}.default;

        # Interim until nixpkgs PR merges — github:Nytelife26/nixpkgs/helium/init
        helium = helium.legacyPackages.${system}.helium;

        # nixpkgs#426717 — koffydrop: doCheck off only for i686, keeps x86_64 openldap cached
        openldap = prev.openldap.overrideAttrs (_: {
          doCheck = !prev.stdenv.hostPlatform.isi686;
        });

        # azahar 2125.1.3: glibc 2.42 no longer transitively provides cstring
        # https://github.com/azahar-emu/azahar/pull/2232
        azahar = prev.azahar.overrideAttrs (old: {
          postPatch = (old.postPatch or "") + ''
            sed -i '1i#include <cstring>' src/audio_core/cubeb_sink.cpp src/audio_core/cubeb_input.cpp
          '';
        });

        # aseprite 1.3.18 + fmt 12: fmt::format moved out of fmt/core.h
        # (quoted include in strings.h; nixpkgs added this in a later bump)
        aseprite = prev.aseprite.overrideAttrs (old: {
          postPatch = (old.postPatch or "") + ''
            if grep -q '"fmt/core.h"' src/app/i18n/strings.h; then
              substituteInPlace src/app/i18n/strings.h \
                --replace-fail '"fmt/core.h"' '"fmt/format.h"'
            fi
          '';
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

      # Headless server — nixos-remote-install --flake .#abacab (see hosts/abacab/disk.nix).
      nixosConfigurations.abacab = mkNixosHost {
        inherit system;
        modules = [
          ./hosts/abacab
          disko.nixosModules.disko
        ];
        homeModules = [
          ./home/potter
          ./hosts/abacab/home.nix
        ];
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
