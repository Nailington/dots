#!/bin/sh
# Privileged helper for the DankMaterialShell acerSense plugin.
# Usage: acer-ctl {profile|fan|battery-limit|usb-charging|gpu} <value>
set -eu

PROFILE_SYS=/sys/firmware/acpi/platform_profile

# linuwu-sense exposes either nitro_sense (Nitro) or predator_sense (Predator).
NS=""
for d in /sys/devices/platform/acer-wmi/nitro_sense /sys/devices/platform/acer-wmi/predator_sense; do
    [ -d "$d" ] && NS="$d" && break
done

need_ns() { [ -n "$NS" ] || { echo "linuwu-sense não encontrado (nitro_sense/predator_sense ausente)" >&2; exit 1; }; }

action="${1:-}"
value="${2:-}"

case "$action" in
    profile)
        case "$value" in
            low-power|quiet|balanced|balanced-performance|performance)
                printf '%s' "$value" > "$PROFILE_SYS" ;;
            *) echo "profile: low-power|quiet|balanced|balanced-performance|performance" >&2; exit 1 ;;
        esac ;;
    fan)
        need_ns
        case "$value" in
            auto)  printf '%s' "0,0"     > "$NS/fan_speed" ;;
            max)   printf '%s' "100,100" > "$NS/fan_speed" ;;
            quiet) printf '%s' "40,40"   > "$NS/fan_speed" ;;
            0|[1-9]|[1-9][0-9]|100)
                printf '%s' "$value,$value" > "$NS/fan_speed" ;;
            *) echo "fan: auto|quiet|max|0-100" >&2; exit 1 ;;
        esac ;;
    battery-limit)
        need_ns
        case "$value" in
            on)  printf '%s' "1" > "$NS/battery_limiter" ;;
            off) printf '%s' "0" > "$NS/battery_limiter" ;;
            *) echo "battery-limit: on|off" >&2; exit 1 ;;
        esac ;;
    usb-charging)
        need_ns
        case "$value" in
            off)      printf '%s' "0"      > "$NS/usb_charging" ;;
            10|20|30) printf '%s' "$value" > "$NS/usb_charging" ;;
            *) echo "usb-charging: off|10|20|30" >&2; exit 1 ;;
        esac ;;
    gpu)
        case "$value" in
            hybrid|integrated|nvidia)
                command -v envycontrol >/dev/null 2>&1 || { echo "envycontrol não encontrado" >&2; exit 1; }
                envycontrol -s "$value" ;;
            *) echo "gpu: hybrid|integrated|nvidia" >&2; exit 1 ;;
        esac ;;
    *)
        echo "uso: acer-ctl {profile|fan|battery-limit|usb-charging|gpu} <valor>" >&2
        exit 1 ;;
esac
