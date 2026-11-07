{ config, lib, pkgs, inputs, ... }:

let
  # Satellite provides a scaling-only XSettings manager and yields when another
  # manager claims the selection. GNOME normally refuses that handover.
  dmsXsettings = pkgs.gnome-settings-daemon.overrideAttrs (old: {
    postPatch = (old.postPatch or "") + ''
      substituteInPlace plugins/xsettings/gsd-xsettings-manager.c \
        --replace-fail 'if (xsettings_manager_check_running (' \
          'if (FALSE && xsettings_manager_check_running ('
    '';
  });
  # DMS must own writable theme copies and generated CSS; HM must not pin
  # gtk-theme, color-scheme, or gtk-application-prefer-dark-theme.
  dmsGtkSetup = pkgs.writeShellApplication {
    name = "dms-gtk-setup";
    runtimeInputs = [ pkgs.bash pkgs.coreutils pkgs.gnugrep pkgs.gnused pkgs.dconf ];
    text = ''
      config_dir=${lib.escapeShellArg config.xdg.configHome}
      export XDG_DATA_DIRS=${pkgs.adw-gtk3}/share:''${XDG_DATA_DIRS:-/usr/local/share:/usr/share}
      mkdir -p "$config_dir/gtk-3.0" "$config_dir/gtk-4.0"
      # On a fresh home, DMS generates these after its first theme worker runs.
      for version in 3 4; do
        colors="$config_dir/gtk-$version.0/dank-colors.css"
        if [[ ! -e "$colors" ]]; then
          touch "$colors"
        fi
      done

      # Retire the old Breeze-only stylesheet, keeping it available to restore.
      gtk3_css="$config_dir/gtk-3.0/gtk.css"
      if [[ -f "$gtk3_css" && ! -L "$gtk3_css" ]] &&
         [[ $(cat "$gtk3_css") == "@import 'colors.css';" ]]; then
        mv --backup=numbered "$gtk3_css" "$gtk3_css.pre-dms"
      fi

      is_light=false
      theme=adw-gtk3-dark
      if [[ $(dconf read /org/gnome/desktop/interface/color-scheme) == "'default'" ||
            $(dconf read /org/gnome/desktop/interface/color-scheme) == "'prefer-light'" ]]; then
        is_light=true
        theme=adw-gtk3
      fi
      # Use upstream's NixOS-aware copy/patch logic, including upgrade detection.
      bash ${inputs.dms}/quickshell/scripts/gtk.sh "$config_dir" apply "$is_light"
      # Upstream uses 2 for skipped and 3 for already current; both are harmless.
      patch_status=0
      bash ${inputs.dms}/quickshell/scripts/gtk.sh "$config_dir" patch "$is_light" || patch_status=$?
      case "$patch_status" in
        0|2|3) ;;
        *) exit "$patch_status" ;;
      esac
      dconf write /org/gnome/desktop/interface/gtk-theme "'$theme'"
    '';
  };
in
{
  # Publish DMS's dconf settings over XSettings for all X11 GTK apps, including
  # apps whose bundled GLib cannot load the system dconf backend (VMware).
  # Run only this GNOME plugin; the rest of the session remains niri + DMS.
  systemd.user.services.dms-xsettings = {
    Unit = {
      Description = "DMS GTK settings for XWayland applications";
      # niri imports DISPLAY before signaling session readiness. Starting at
      # graphical-session-pre can race that import and exit without an X display.
      After = [ "graphical-session.target" ];
      PartOf = [ "graphical-session.target" ];
    };
    Service = {
      ExecStart = "${dmsXsettings}/libexec/gsd-xsettings";
      Environment = [ "GDK_BACKEND=x11" ];
      # Initialization can fail with exit status 0, so on-failure misses it.
      Restart = "always";
      RestartSec = 2;
    };
    Install.WantedBy = [ "graphical-session.target" ];
  };
  systemd.user.services.dms.Service = {
    ExecStartPre = [ (lib.getExe dmsGtkSetup) ];
    # Ask upstream DMS to refresh running GTK4 apps after generating new CSS.
    Environment = [ "DMS_ENABLE_GTK_REFRESH=1" ];
  };
}
