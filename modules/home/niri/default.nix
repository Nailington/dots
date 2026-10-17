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
      bash ${inputs.dms}/quickshell/scripts/gtk.sh "$config_dir" patch "$is_light"
      dconf write /org/gnome/desktop/interface/gtk-theme "'$theme'"
    '';
  };
  planCState = "${config.xdg.stateHome}/niri/plan-c.kdl";
  planCOff = pkgs.writeText "niri-plan-c-off.kdl" ''
    // Plan C: OFF
    include "${config.xdg.configHome}/niri/dms/binds.kdl"
    // Override the default Super+Tab switcher; it opens the overview instead.
    recent-windows {
        binds {
            Alt+Tab         { next-window scope="output"; }
            Alt+Shift+Tab   { previous-window scope="output"; }
            Alt+grave       { next-window filter="app-id"; }
            Alt+Shift+grave { previous-window filter="app-id"; }
        }
    }
  '';
  planCOn = pkgs.writeText "niri-plan-c-on.kdl" ''
    // Plan C: ON
    // No normal binds are included, so keyboard and wheel shortcuts pass through.
    // Mod3 (ISO_Level5_Shift) is unmapped on our keyboard: Alt/Super/Ctrl/Shift
    // mouse clicks can no longer trigger niri's built-in move/resize gestures.
    input {
        mod-key "Mod3"
        mod-key-nested "Mod3"
    }
    recent-windows { off; }
    layout {
        focus-ring {
            on
            width 4
            active-color "#00e5ff"
        }
    }
  '';
  planC = pkgs.writeShellApplication {
    name = "plan-c";
    runtimeInputs = [ pkgs.coreutils pkgs.gnugrep pkgs.gnused pkgs.util-linux pkgs.niri pkgs.libnotify ];
    text = ''
      state_file=${lib.escapeShellArg planCState}
      config_dir=${lib.escapeShellArg "${config.xdg.configHome}/niri"}
      state_dir=$(dirname "$state_file")
      mkdir -p "$state_dir"
      exec 9>"$state_dir/plan-c.lock"
      flock 9

      state=off
      if grep -q '^// Plan C: ON$' "$state_file" 2>/dev/null; then
        state=on
      fi
      action=''${1:-toggle}
      case "$action" in
        toggle) if [[ "$state" == on ]]; then state=off; else state=on; fi ;;
        on|off) state=$action ;;
        status) ;;
        *) echo 'Usage: plan-c [toggle|on|off|status] [--quiet]' >&2; exit 2 ;;
      esac

      if [[ "$action" != status ]]; then
        candidate=$(mktemp "$state_dir/.plan-c.XXXXXX")
        check=$(mktemp "$config_dir/.plan-c-check.XXXXXX")
        trap 'rm -f "$candidate" "$check"' EXIT
        if [[ "$state" == on ]]; then
          cp ${planCOn} "$candidate"
        else
          cp ${planCOff} "$candidate"
        fi
        # Validate the whole config in its own directory, with the candidate
        # replacing the active include, so relative DMS includes still resolve.
        sed "s|^include \"plan-c.kdl\"$|include \"$candidate\"|" \
          "$config_dir/config.kdl" > "$check"
        niri validate --config "$check"
        mv -f "$candidate" "$state_file"
      fi

      echo "Plan C: $state"
      if [[ "''${2:-}" != --quiet ]]; then
        notification_id=0
        if [[ -f "$state_dir/notification-id" ]]; then
          read -r notification_id < "$state_dir/notification-id"
        fi
        if [[ "$state" == on ]]; then
          title='Plan C ON — desktop shortcuts blocked'
          body='Alt+Shift+Backslash restores shortcuts. Thick cyan focus ring = ON.'
          timeout=0
        else
          title='Plan C OFF — desktop shortcuts restored'
          body='Alt+Shift+Backslash enables gaming mode.'
          timeout=4000
        fi
        # Replace the ON notification when restoring shortcuts. DMS displays
        # timeout=0 notifications until dismissed; the focus ring also shows ON.
        if id=$(notify-send --app-name='Plan C' --icon=input-gaming \
          --print-id --replace-id="$notification_id" --expire-time="$timeout" \
          "$title" "$body"); then
          printf '%s\n' "$id" > "$state_dir/notification-id"
        fi
      fi
    '';
  };
in
{
  # niri + DankMaterialShell. Do not import modules/home/hyprland.
  imports = [
    inputs.dms.homeModules.dank-material-shell
  ];

  # Don't let niri-flake generate config.kdl; we ship it from this directory.
  programs.niri.config = null;

  # Publish DMS's dconf settings over XSettings for all X11 GTK apps, including
  # apps whose bundled GLib cannot load the system dconf backend (VMware).
  # Run only this GNOME plugin; the rest of the session remains niri + DMS.
  systemd.user.services.dms-xsettings = {
    Unit = {
      Description = "DMS GTK settings for XWayland applications";
      After = [ "graphical-session-pre.target" ];
      PartOf = [ "graphical-session.target" ];
    };
    Service = {
      ExecStart = "${dmsXsettings}/libexec/gsd-xsettings";
      Environment = [ "GDK_BACKEND=x11" ];
      Restart = "on-failure";
    };
    Install.WantedBy = [ "graphical-session.target" ];
  };
  systemd.user.services.dms.Service = {
    ExecStartPre = [ (lib.getExe dmsGtkSetup) ];
    # Ask upstream DMS to refresh running GTK4 apps after generating new CSS.
    Environment = [ "DMS_ENABLE_GTK_REFRESH=1" ];
  };

  home.packages = [ planC ];
  # Only this include is mutable. Keep config.kdl and DMS bindings declarative.
  xdg.configFile."niri/plan-c.kdl".source = config.lib.file.mkOutOfStoreSymlink planCState;
  home.activation.initializePlanC = lib.hm.dag.entryBetween [ "linkGeneration" ] [ "writeBoundary" ] ''
    run mkdir -p ${lib.escapeShellArg "${config.xdg.stateHome}/niri"}
    if [ ! -e ${lib.escapeShellArg planCState} ]; then
      run cp ${planCOff} ${lib.escapeShellArg planCState}
      run chmod u+w ${lib.escapeShellArg planCState}
    fi
  '';

  xdg.configFile."niri/config.kdl".source = ./config.kdl;
  xdg.configFile."niri/dms" = {
    source = ./dms;
    recursive = true;
  };
  # libexec is not on PATH; niri spawn-at-startup is the Hyprland exec-once equivalent.
  xdg.configFile."niri/pam-kwallet.kdl".text = ''
    spawn-at-startup "${pkgs.kdePackages.kwallet-pam}/libexec/pam_kwallet_init"
  '';

  programs.dank-material-shell = {
    enable = true;
    systemd = {
      enable = true;
      restartIfChanged = true;
    };

    enableSystemMonitoring = true;
    enableVPN = true;
    enableDynamicTheming = true;
    enableAudioWavelength = true;
  };
}
