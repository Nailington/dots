{ config, lib, pkgs, inputs, ... }:

let
  flakeDirectory = config.potter.flakeDirectory;
  niriDirectory = "${flakeDirectory}/modules/home/niri";
  writableFile = config.lib.file.mkOutOfStoreSymlink;
  dmsFragments = lib.filterAttrs
    (name: type: type == "regular" && lib.hasSuffix ".kdl" name)
    (builtins.readDir ./dms);
  steamFixCursor = pkgs.writeShellApplication {
    name = "steam-fix-cursor";
    runtimeInputs = [ pkgs.coreutils pkgs.procps pkgs.jq pkgs.niri pkgs.xlsclients pkgs.xrandr pkgs.util-linux pkgs.gawk pkgs.gnused ];
    text = ''
      if [[ $# -gt 0 ]]; then
        echo 'Usage: steam-fix-cursor' >&2
        exit 2
      fi
      if [[ -z "''${NIRI_SOCKET:-}" || ! "''${DISPLAY:-}" =~ ^:[0-9]+(\.0)?$ ]]; then
        echo 'Run this command inside your niri desktop session.' >&2
        exit 1
      fi
      command -v steam >/dev/null
      exec 9>"$XDG_RUNTIME_DIR/steam-fix-cursor.lock"
      flock -n 9 || { echo 'Steam cursor recovery is already running.' >&2; exit 1; }

      # Match only the satellite serving this DISPLAY, including Nix's wrapper.
      display=''${DISPLAY%.0}
      satellite_pattern="^xwayland-satellite $display( |$)"
      satellite=$(pgrep -u "$UID" -f "$satellite_pattern" || true)
      if [[ ! "$satellite" =~ ^[0-9]+$ ]]; then
        echo 'Could not identify a single XWayland satellite for this display.' >&2
        exit 1
      fi

      # Niri reports satellite's PID for X11 windows. Check these as well as
      # WM_COMMAND clients, since games do not always appear in xlsclients.
      other_windows=$(niri msg --json windows | jq -r --argjson pid "$satellite" '
        .[] | select(.pid == $pid and .app_id != "steam") | .title')
      other_clients=$(xlsclients | awk '$2 != "steam" && $2 != "steamwebhelper"')
      if [[ -n "$other_windows$other_clients" ]]; then
        printf 'Close these XWayland apps/games first, then run steam-fix-cursor again:\n%s\n%s\n' \
          "$other_windows" "$other_clients" >&2
        exit 1
      fi

      echo 'Closing Steam cleanly…'
      if pgrep -u "$UID" -x steam >/dev/null; then
        timeout 15s steam -shutdown
      fi
      for ((attempt = 0; attempt < 30; attempt++)); do
        if ! pgrep -u "$UID" -x 'steam|steamwebhelper' >/dev/null; then
          break
        fi
        sleep 1
      done
      if pgrep -u "$UID" -x 'steam|steamwebhelper' >/dev/null; then
        echo 'Steam has not exited. Close it and any running games, then retry.' >&2
        exit 1
      fi

      # Recheck before resetting: another X11 app might have opened meanwhile.
      if [[ -n "$(xlsclients)" ]] ||
         ! niri msg --json windows | jq -e --argjson pid "$satellite" \
           'all(.[]; .pid != $pid)' >/dev/null; then
        echo 'An XWayland app is still open; leaving XWayland running. Close it and retry.' >&2
        exit 1
      fi
      if [[ $(pgrep -u "$UID" -f "$satellite_pattern") != "$satellite" ]]; then
        echo 'XWayland changed during recovery; run steam-fix-cursor again.' >&2
        exit 1
      fi

      echo 'Resetting XWayland display information…'
      kill -TERM "$satellite"
      for ((attempt = 0; attempt < 50; attempt++)); do
        if ! kill -0 "$satellite" 2>/dev/null; then
          break
        fi
        sleep 0.1
      done
      if kill -0 "$satellite" 2>/dev/null; then
        echo 'XWayland has not stopped; run steam-fix-cursor again.' >&2
        exit 1
      fi
      # Connecting starts a fresh satellite through niri's on-demand integration.
      xrandr --current | sed -n '1,3p'
      niri msg action spawn -- steam
      echo 'Steam reopened. Try the mouse at the screen edges.'
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
    ./dms-services.nix
  ];

  # Don't let niri-flake generate config.kdl; we ship it from this directory.
  programs.niri.config = null;

  home.packages = [ planC ] ++ lib.optionals pkgs.stdenv.hostPlatform.isx86_64 [ steamFixCursor ];
  xdg.desktopEntries.steam-fix-cursor = lib.mkIf pkgs.stdenv.hostPlatform.isx86_64 {
    name = "Fix Steam cursor";
    comment = "Refresh stale XWayland display information and reopen Steam";
    exec = lib.getExe steamFixCursor;
    icon = "steam";
    terminal = true;
    categories = [ "Game" ];
  };
  # Session state stays outside Git; DMS preferences and fragments use the checkout.
  home.activation.initializePlanC = lib.hm.dag.entryBetween [ "linkGeneration" ] [ "writeBoundary" ] ''
    run mkdir -p ${lib.escapeShellArg "${config.xdg.stateHome}/niri"}
    if [ ! -e ${lib.escapeShellArg planCState} ]; then
      run cp ${planCOff} ${lib.escapeShellArg planCState}
      run chmod u+w ${lib.escapeShellArg planCState}
    fi
    # Hosts without tracked monitor settings get a writable, autodetected default.
    if [ ! -e ${lib.escapeShellArg "${config.xdg.stateHome}/niri/outputs.kdl"} ]; then
      run touch ${lib.escapeShellArg "${config.xdg.stateHome}/niri/outputs.kdl"}
    fi
  '';

  # DMS resolves these links before replacing files, so its writes update Git's
  # working tree rather than failing against /nix/store. Keep settings/session
  # unset in the upstream module: generated store files would be read-only.
  xdg.configFile = lib.mapAttrs' (name: _: lib.nameValuePair "niri/dms/${name}" {
    source = writableFile "${niriDirectory}/dms/${name}";
  }) dmsFragments // {
    "niri/plan-c.kdl".source = writableFile planCState;
    "dms/settings.json".source = writableFile "${niriDirectory}/settings.json";
    "niri/config.kdl".source = writableFile "${niriDirectory}/config.kdl";
    "niri/dms/outputs.kdl".source = lib.mkDefault (
      writableFile "${config.xdg.stateHome}/niri/outputs.kdl"
    );
    # libexec is not on PATH; niri spawn-at-startup is the Hyprland exec-once equivalent.
    "niri/pam-kwallet.kdl".text = ''
      spawn-at-startup "${pkgs.kdePackages.kwallet-pam}/libexec/pam_kwallet_init"
    '';
  };
  # Fail before changing the home rather than install dangling desktop links.
  home.activation.checkDesktopCheckout = lib.hm.dag.entryBefore [ "writeBoundary" ] ''
    if [ ! -f ${lib.escapeShellArg "${niriDirectory}/settings.json"} ] ||
       [ ! -f ${lib.escapeShellArg "${niriDirectory}/config.kdl"} ]; then
      echo ${lib.escapeShellArg "DMS needs a local flake checkout at ${flakeDirectory}; clone/pull it before switching, or set potter.flakeDirectory."} >&2
      exit 1
    fi
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
