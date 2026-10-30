{
  description = "Potter's NixOS Configuration";

  inputs = {   
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable-small";

    # Pi 5 needs newer boot firmware/U-Boot than the existing x86_64 pin.
    nixpkgs-aarch64.url = "github:NixOS/nixpkgs/nixos-unstable";
    nixos-hardware = {
      url = "github:NixOS/nixos-hardware";
      inputs.nixpkgs.follows = "nixpkgs-aarch64";
    };

    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Intel Mac (x86_64-darwin) is unsupported on nixos-unstable/26.11.
    # Keep Linux on nixos-unstable-small; Darwin follows 26.05 until it EOL's end of 2026.
    nixpkgs-unstable.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    nixpkgs-darwin.url = "github:NixOS/nixpkgs/nixpkgs-26.05-darwin";


    darwin = {
      url = "github:nix-darwin/nix-darwin/nix-darwin-26.05";
      # inputs.nixpkgs.follows = "nixpkgs-darwin";
    };

    home-manager-darwin = {
      url = "github:nix-community/home-manager/release-26.05";
      # inputs.nixpkgs.follows = "nixpkgs-darwin";
    };

    # Darwin-only. Do not import determinate.nixosModules on Linux hosts.
    determinate.url = "https://flakehub.com/f/DeterminateSystems/determinate/3";

    nix-homebrew.url = "github:zhaofengli/nix-homebrew";

    homebrew-core = {
      url = "github:homebrew/homebrew-core";
      flake = false;
    };

    homebrew-cask = {
      url = "github:homebrew/homebrew-cask";
      flake = false;
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
    nix-cachyos-kernel.url = "github:xddxdd/nix-cachyos-kernel";

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

    dms = {
      url = "github:AvengeMedia/DankMaterialShell";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    dank-greeter = {
      url = "github:AvengeMedia/dank-greeter";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Needed for DMS niri.includes (rewrites config.kdl). Package still comes from nixpkgs.
    niri = {
      url = "github:sodiboo/niri-flake";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    qtengine = {
      url = "github:kossLAN/qtengine";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Unofficial ChatGPT Community desktop (codex-desktop). Follow nixpkgs so
    # the wrapper's runtime libraries match this system's nix-ld.
    # https://github.com/ilysenko/codex-desktop-linux/blob/main/docs/nix.md
    codex-desktop-linux = {
      url = "github:ilysenko/codex-desktop-linux";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    sim-relay = {
      url = "github:Nailington/sim-relay";
      inputs.nixpkgs.follows = "nixpkgs";
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
      disko,
      ...
    }@inputs:
    let
      system = "x86_64-linux";

      inherit (import ./lib/hosts.nix { inherit self inputs; })
        mkNixosHost
        mkHomeConfiguration
        mkDarwinHost
        ;

      linuxSystems = [ "x86_64-linux" "aarch64-linux" ];
      pkgsFor = platform: import
        (if platform == "aarch64-linux" then inputs.nixpkgs-aarch64 else nixpkgs) {
        system = platform;
        config = {
          allowUnfree = true;
        };
        overlays = [ self.overlays.default ];
      };
      pkgs = pkgsFor system;
    in
    {
      packages = nixpkgs.lib.genAttrs linuxSystems (system:
        let
          pkgs = pkgsFor system;
          inherit
            (import ./pkgs/nh-wrapped.nix {
              inherit pkgs;
              syncAgeRecipientsText = builtins.readFile ./scripts/sync-age-recipients.sh;
            })
            sync-age-recipients
            nh
            ;
          nixos-anywhere-unwrapped =
            inputs.nixos-anywhere.packages.${system}.nixos-anywhere
              or inputs.nixos-anywhere.packages.${system}.default;
        in
        {
          inherit sync-age-recipients nh;
          update-local-packages = (pkgs.writeShellApplication {
            name = "update-local-packages";
            runtimeInputs = [
              # nix-update captures hash-fetching stderr to parse the result.
              # Tee it to the terminal while retaining that captured output.
              (pkgs.nix-update.overrideAttrs (old: {
                patches = (old.patches or [ ]) ++ [ ./pkgs/nix-update-stream-logs.patch ];
              }))
            ] ++ (with pkgs; [ nix git coreutils diffutils ]);
            text = builtins.readFile ./scripts/update-local-packages.sh;
          }).overrideAttrs (old: {
            nativeBuildInputs = (old.nativeBuildInputs or [ ]) ++ [ pkgs.installShellFiles ];
            buildCommand = old.buildCommand + ''
              cat > _update-local-packages <<'EOF'
              #compdef update-local-packages

              local state package description
              local -a packages options selected
              local have_package=false
              selected=("''${(@)words[2,CURRENT-1]}")

              # --list is read-only and keeps completion in sync with the updater.
              while read -r package description; do
                if (( ''${selected[(Ie)$package]} )); then
                  have_package=true
                else
                  packages+=("$package:$description")
                fi
              done < <(update-local-packages --list)

              options=(
                '(-h --help --list *)'{-h,--help}'[Show help]'
                '(-h --help --list *)--list[Show supported packages and update policies]'
                '--build[Build each updated package]'
                '--flake[Local flake checkout]:directory:_directories'
              )
              if ! $have_package; then
                options+=('(*)--all[Update all supported packages]')
              fi

              _arguments -C "$options[@]" '(--all)*:package:->packages' && return
              if [[ $state == packages ]]; then
                _describe 'package' packages
              fi
              EOF
              installShellCompletion --zsh _update-local-packages
            '';
          });
          google-sans = pkgs.google-sans;
          google-sans-flex = pkgs.google-sans-flex;
          t3code = pkgs.t3code;
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
        } // pkgs.lib.optionalAttrs (system == "x86_64-linux") {
          inherit (pkgs) althea singularcard twitch-drops-miner auto-rob kde-craft sweetpad sim-relay;
          sweetpad-vscode = pkgs.sweetpad.vscodeExtension;
        });

      overlays.default = final: prev:
      let
        system = final.stdenv.hostPlatform.system;
        # Override before buildDotnetModule resolves the NuGet dependency files.
        discordChatExporterFork = package: nugetDeps: package.override {
          buildDotnetModule = args: final.buildDotnetModule (finalAttrs:
            let old = args finalAttrs;
            in old // {
              version = "2.48.1";
              src = final.fetchFromGitHub {
                owner = "Nailington";
                repo = "DiscordChatExporter";
                tag = finalAttrs.version;
                hash = "sha256-PRPlTy7FjgzA55ns52DGfvE/F1MY9fU7n/muQQfMyqo=";
              };
              inherit nugetDeps;
              meta = old.meta // {
                homepage = "https://github.com/Nailington/DiscordChatExporter";
                changelog = "https://github.com/Nailington/DiscordChatExporter/releases/tag/${finalAttrs.version}";
              };
            });
        };
      in {
        rofi-themes-collection = final.callPackage ./pkgs/rofi-themes {
          rofiThemesSrc = rofi-themes;
        };
        posys-cursor-scalable = final.callPackage ./pkgs/posys-cursor-scalable { };
        seguiemj = final.callPackage ./pkgs/seguiemj { };
        hojas-de-plata = final.callPackage ./pkgs/hojas-de-plata { };
        google-sans = final.callPackage ./pkgs/google-sans { };
        google-sans-flex = final.callPackage ./pkgs/google-sans-flex { };
        althea = final.callPackage ./pkgs/althea { };
        singularcard = final.callPackage ./pkgs/singularcard { };
        cider = final.callPackage ./pkgs/cider { };
        twitch-drops-miner = final.callPackage ./pkgs/twitch-drops-miner { };
        auto-rob = final.callPackage ./pkgs/auto-rob { };
        kde-craft = final.callPackage ./pkgs/kde-craft { };
        sweetpad = final.callPackage ./pkgs/sweetpad { };
        sim-relay = inputs.sim-relay.packages.${system}.default;

        discordchatexporter-cli = (discordChatExporterFork prev.discordchatexporter-cli
          ./pkgs/discordchatexporter/cli-deps.json).overrideAttrs (_: {
          # SQLite and HttpCloak add native libraries; only wrap the CLI itself.
          dotnetExecutables = [ "DiscordChatExporter.Cli" ];
        });
        discordchatexporter-desktop = (discordChatExporterFork prev.discordchatexporter-desktop
          ./pkgs/discordchatexporter/desktop-deps.json).overrideAttrs (_: {
          # Keep the existing Nix package's XDG config path for saved settings.
          postPatch = ''
            substituteInPlace DiscordChatExporter.Gui/StartOptions.cs \
              --replace-fail 'Environment.SpecialFolder.LocalApplicationData' 'Environment.SpecialFolder.ApplicationData' \
              --replace-fail 'SettingsDirectoryName = "DiscordChatExporter"' 'SettingsDirectoryName = "discordchatexporter"'
          '';
        });

        # Pin the published nightly and its dependencies together.
        t3code = let
          unwrapped = prev.t3code.unwrapped.overrideAttrs (finalAttrs: old: {
            version = "0.1.6-nightly.20261029.3892";
            src = final.fetchFromGitHub {
              owner = "pingdotgg";
              repo = "t3code";
              rev = "v0.1.6-nightly.20261029.3892";
              hash = "sha256-FFPC549L0Q1N0YSHK4BdSVQL1/mu0nGTqBhGtplSgxI=";
            };
            pnpmDeps = old.pnpmDeps.override {
              inherit (finalAttrs) src version;
              hash = "sha256-uj7IxNMdubCtIqkv1M/vg5dRTeUaysC+1l/7ag+D7/4=";
            };
            meta = old.meta // {
              changelog = "https://github.com/pingdotgg/t3code/releases/tag/v${finalAttrs.version}";
            };
          });
        in (prev.t3code.override { t3code-unwrapped = unwrapped; }).overrideAttrs (old: {
          nativeBuildInputs = (old.nativeBuildInputs or []) ++ [ final.makeWrapper ];
          # node-pty's Linux prebuild lacks a C++ runtime search path.
          # Drop the LD_LIBRARY_PATH additions once nixpkgs#569702 reaches the input.
          # symlinkJoin embeds postBuild in buildCommand before overrideAttrs.
          buildCommand = old.buildCommand + ''
            wrapProgramBinary "$out/bin/t3" \
              --prefix LD_LIBRARY_PATH : ${final.lib.makeLibraryPath [ final.stdenv.cc.cc.lib ]}
            # The background service owns ~/.t3; pair with it for existing threads.
            # Expand HOME at launch time, while allowing an explicit T3CODE_HOME.
            wrapProgramShell "$out/bin/t3code-desktop" \
              --prefix LD_LIBRARY_PATH : ${final.lib.makeLibraryPath [ final.stdenv.cc.cc.lib ]} \
              --run 'export T3CODE_HOME="''${T3CODE_HOME:-$HOME/.t3-desktop}"'
          '';
        });

        # VMware ships GTK 3.14, which cannot render DMS's modern adw-gtk3
        # theme. Keep VMware's C++ interfaces (old gtkmm ABI), but load the
        # system C GTK stack and font libraries through its system-lib mode.
        vmware-workstation = let
          # Newer patchelf versions move vmnet-natd's .dynamic into a read-only
          # LOAD segment, crashing ld.so when it writes DT_DEBUG at startup.
          vmwarePatchelf = prev.patchelf.overrideAttrs (_: {
            version = "0.15.2";
            src = prev.fetchurl {
              url = "https://github.com/NixOS/patchelf/releases/download/0.15.2/patchelf-0.15.2.tar.bz2";
              hash = "sha256-F3RfVkFZyOIo/EEtplogSLhGxLa0Igt3y/IkFuAvLXw=";
            };
          });
          workstation = prev.vmware-workstation.overrideAttrs (old: {
            nativeBuildInputs = [ vmwarePatchelf ] ++ (old.nativeBuildInputs or []);
            # nixpkgs omits the bundled Windows Tools image; the install menu
            # looks for it under the package's own libdir/isoimages.
            postInstall = (old.postInstall or "") + ''
              install -m644 unpacked/vmware-tools-windows/windows.iso \
                "$out/lib/vmware/isoimages/windows.iso"
            '';
          });
        in final.symlinkJoin {
          name = "vmware-workstation-${workstation.version}";
          inherit (workstation) version meta;
          paths = [ workstation ];
          nativeBuildInputs = [ final.makeWrapper ];
          postBuild = ''
            # System GTK also needs its schemas and image loaders; VMware's
            # bundled GTK data does not match the libraries loaded above.
            for program in vmware vmplayer; do
              wrapProgram "$out/bin/$program" \
                --set VMWARE_USE_SYSTEM_LIBS 1 \
                --set GDK_BACKEND x11 \
                --set GSETTINGS_SCHEMA_DIR ${final.gtk3}/share/gsettings-schemas/${final.gtk3.name}/glib-2.0/schemas \
                --set GDK_PIXBUF_MODULE_FILE ${final.librsvg}/${final.gdk-pixbuf.binaryDir}/loaders.cache \
                --set-default XDG_DATA_DIRS /usr/local/share:/usr/share \
                --prefix XDG_DATA_DIRS : ${final.lib.makeSearchPath "share" (with final; [ shared-mime-info hicolor-icon-theme adwaita-icon-theme ])}:${final.gsettings-desktop-schemas}/share/gsettings-schemas/${final.gsettings-desktop-schemas.name} \
                --prefix LD_LIBRARY_PATH : ${final.lib.makeLibraryPath (with final; [
                  stdenv.cc.cc.lib gtk3 glib cairo pango fontconfig gdk-pixbuf
                  at-spi2-core expat freetype harfbuzz fribidi pixman libpng
                ])}
            done
            # Upstream desktop entries use absolute paths, bypassing PATH.
            for desktop in vmware-workstation.desktop vmware-player.desktop; do
              cp --remove-destination \
                ${workstation}/share/applications/$desktop \
                "$out/share/applications/$desktop"
              chmod u+w "$out/share/applications/$desktop"
              substituteInPlace "$out/share/applications/$desktop" \
                --replace-fail '${workstation}/bin/' "$out/bin/"
            done
          '';
        };

        # Keep ARM tools on custard's package pin; preserve the x86 flake build.
        nix-index = if system == "aarch64-linux" then prev.nix-index
          else nix-index.packages.${system}.default;

        # Interim until nixpkgs PR merges — github:Nytelife26/nixpkgs/helium/init
        helium = helium.legacyPackages.${system}.helium;

        # libguestfs is marked broken because guestmount still needs FUSE 2.
        # OSX-KVM uses guestfish, so build without the optional FUSE support.
        # https://libguestfs.org/guestfs-building.1.html
        libguestfs = prev.libguestfs.overrideAttrs (old: {
          buildInputs = final.lib.remove prev.fuse old.buildInputs;
          configureFlags = old.configureFlags ++ [ "--disable-fuse" ];
          meta = old.meta // { broken = false; };
        });

        # sphinxHook reads only the first array item with structured attrs,
        # skipping khal's man output. Remove once the hook handles arrays.
        khal = prev.khal.overrideAttrs (_: {
          sphinxBuilders = "html man";
        });

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
        extraOverlays = [
          nix-cachyos-kernel.overlays.pinned
        ];
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

      # Raspberry Pi 5 — microSD boot, niri + DMS, native aarch64 packages.
      nixosConfigurations.custard = mkNixosHost {
        system = "aarch64-linux";
        modules = [
          ./hosts/custard
          inputs.nixos-hardware.nixosModules.raspberry-pi-5
          disko.nixosModules.disko
        ];
        homeModules = [
          ./home/potter
          ./hosts/custard/home.nix
        ];
      };

      # 2017 Intel iMac (OCLP). nix-darwin-26.05 + nixpkgs-26.05-darwin (Intel dropped
      # in 26.11). Homebrew via nix-homebrew. Home: zsh/OMZ only — not Linux modules.
      darwinConfigurations.ewbtciast = mkDarwinHost {
        system = "x86_64-darwin";
        modules = [ ./hosts/ewbtciast ];
        homeModules = [ ./hosts/ewbtciast/home.nix ];
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

      # FHS sandbox + wrappers. Craft itself lives in ~/CraftRoot (writable).
      devShells.${system}.craft = pkgs.kde-craft.devShell;
    };
}
