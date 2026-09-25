# Desktops

A host picks **one greeter stack**. The choice is the import list in `hosts/<name>/default.nix` and `hosts/<name>/home.nix`.

| Stack | NixOS module | Home module | Greeter | Status on roundabout |
| --- | --- | --- | --- | --- |
| niri + DankMaterialShell | `modules/nixos/niri.nix` | `modules/home/niri` | greetd + dms-greeter | enabled |
| Hyprland | `modules/nixos/hyprland.nix` | `modules/home/hyprland` | SDDM (`sddm.nix`) | commented out |
| Plasma 6 | `modules/nixos/plasma.nix` | none (Plasma ships the apps) | SDDM (`sddm.nix`) | commented out |

`modules/nixos/desktop.nix` is the shared base (PipeWire, Bluetooth, udisks2, printing, Firefox, kwallet PAM). Import it with whichever session you enable. It does not start a greeter.

`niri.nix` asserts that Hyprland and Plasma are off. Hyprland and Plasma can share SDDM; niri cannot share a host with either. When switching roundabout, comment the whole niri pair and uncomment the other pair. Do not leave both greeters enabled.

## niri + DMS

- Package is `pkgs.niri` from nixpkgs. niri-flake is an input because DMS needs `niri.includes` to rewrite `config.kdl`, and because its NixOS module is imported. `programs.niri.package` overrides niri-flake's older `niri-stable`. `niri-flake.cache.enable = false`.
- `programs.niri.config = null` so niri-flake does not generate a config. The source of truth is `modules/home/niri/config.kdl` plus `modules/home/niri/dms/*.kdl`, installed with `xdg.configFile`.
- DMS's polkit agent is the one that runs. `systemd.user.services.niri-flake-polkit.enable = false`.
- `services.gnome.gnome-keyring.enable = mkForce false`. KDE apps use KWallet.
- XWayland: `xwayland-satellite` on PATH (niri starts it). File chooser portal is KDE. Secret portal is kwallet.
- Greeter user `greeter` is in `video`, `render`, `input`.
- `pam_kwallet_init` is not on PATH (`libexec`). niri starts it from `xdg.configFile."niri/pam-kwallet.kdl"`. That is the Hyprland `exec-once` equivalent. Hyprland's own config should keep the same call if Hyprland is turned back on.

DMS plugin helper scripts often assume a distro layout. On NixOS they need a `pkgs.writeShellApplication` (or an existing package) rather than a curl-to-`~/.local` installer.

## KDE apps vs Plasma

`modules/home/kde-apps.nix` is Dolphin, KIO (+ fuse, extras, admin), Ark, KWallet, kwalletmanager, and the KDE games. It exists so a non-Plasma host can keep those apps.

When `modules/nixos/plasma.nix` is enabled, do **not** import `kde-apps.nix`. Plasma 6 already provides that set. `plasma.nix` does not import `kde-apps.nix` for this reason.

Dolphin drive listing needs `services.udisks2` (in `desktop.nix`) and the KIO stack. `kio-admin` is only the elevated `admin://` path; it is not what makes disks show up.

## KWallet

Chrome is wrapped with `--password-store=kwallet6` in `modules/home/desktop.nix`. It will not autodetect KWallet without Plasma.

PAM hooks for `login`, `greetd`, and `sddm` are in `modules/nixos/desktop.nix` (`kdePackages.kwallet-pam`). Unlock-on-login has been flaky (Chrome still prompts until the wallet is opened once). Do not add another unlock script, activation service, or module unless the user asks. Diagnosis first.

## Themes, cursor, fonts

- QT/GTK theme blocks in `modules/home/desktop.nix` stay commented. The niri session uses qtengine (`programs.qtengine` in `modules/nixos/niri.nix`): Breeze style, icons `breeze-dark`, colors from DMS `~/.local/share/color-schemes/DankMatugen.colors`. qt5ct and qt6ct stay installed. Do not set `QT_QPA_PLATFORMTHEME` in `modules/nixos/desktop.nix`; that session variable overrides qtengine.
- Cursor theme package is `posys-cursor-scalable` (hyprcursors). On niri it still needs a real X/hypr cursor theme (`posy-cursors` was installed for that). Check `modules/home/niri/dms/cursor.kdl` and `desktop.nix` before changing it.
- Fonts are system packages in `modules/nixos/common.nix`: RobotoMono Nerd Font, Google fonts, Google Sans Code, `seguiemj`, `hojas-de-plata`, `google-sans`, `google-sans-flex`. The copies under `home.packages` in `desktop.nix` are commented because the system set already covers them.

## Kitty and flameshot

Kitty's files live in `modules/home/kitty/` and are linked into the home. `programs.kitty` settings in `desktop.nix` are commented; the file tree is the config.

Flameshot's ini is `modules/home/flameshot/`, imported by `desktop.nix`, so any desktop host gets it. It is not Hyprland-specific. DMS can replace it later; until that import is removed, leave the module.
