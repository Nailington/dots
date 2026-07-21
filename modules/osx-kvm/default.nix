{ config, lib, pkgs, inputs, ... }:

let
  cfg = config.programs.osx-kvm;

  osxKvmRepo = inputs.osx-kvm;

  dataDirDefault = "$HOME/VMs/osx-kvm";

  ovmfVarsForResolution = res:
    if builtins.pathExists "${osxKvmRepo}/OVMF_VARS-${res}.fd"
    then "OVMF_VARS-${res}.fd"
    else if res == "1920x1080"
    then "OVMF_VARS-1920x1080.fd"
    else "OVMF_VARS-1024x768.fd";

  ovmfFile = ovmfVarsForResolution cfg.resolution;

  # Plain libguestfs has no appliance; guestfish needs libguestfs-with-appliance on NixOS.
  libguestfs = pkgs.libguestfs-with-appliance;

  commonEnv = ''
    set -eu
    DATA_DIR="''${OSX_KVM_DATA_DIR:-${dataDirDefault}}"
    REPO="${osxKvmRepo}"
    mkdir -p "''${DATA_DIR}"
  '';

  osx-kvm-fetch = pkgs.writeShellScriptBin "osx-kvm-fetch" ''
    ${commonEnv}
    cd "''${DATA_DIR}"
    exec ${pkgs.python3}/bin/python "${osxKvmRepo}/fetch-macOS-v2.py" "$@"
  '';

  osx-kvm-prepare = pkgs.writeShellScriptBin "osx-kvm-prepare" ''
    ${commonEnv}
    RES="${cfg.resolution}"
    OVMF_FILE="${ovmfFile}"
    STAGING="''${DATA_DIR}/.opencore-staging"
    STAMP="''${DATA_DIR}/.opencore-resolution"

    if [ ! -e "''${DATA_DIR}/BaseSystem.dmg" ]; then
      echo "Missing BaseSystem.dmg — run osx-kvm-fetch first (choose 8 for Sequoia)." >&2
      exit 1
    fi

    if [ ! -e "''${DATA_DIR}/BaseSystem.img" ]; then
      echo "Converting BaseSystem.dmg → BaseSystem.img …"
      ${pkgs.dmg2img}/bin/dmg2img -i "''${DATA_DIR}/BaseSystem.dmg" "''${DATA_DIR}/BaseSystem.img"
    fi

    if [ ! -e "''${DATA_DIR}/mac_hdd_ng.img" ]; then
      echo "Creating mac_hdd_ng.img (256G qcow2) …"
      ${pkgs.qemu_kvm}/bin/qemu-img create -f qcow2 "''${DATA_DIR}/mac_hdd_ng.img" 256G
    fi

    need_opencore=1
    if [ -f "''${STAMP}" ] && [ "$(cat "''${STAMP}")" = "''${RES}" ] \
        && [ -f "''${DATA_DIR}/OpenCore/OpenCore.qcow2" ] \
        && [ -f "''${DATA_DIR}/''${OVMF_FILE}" ]; then
      need_opencore=0
    fi

    if [ "''${need_opencore}" -eq 1 ]; then
      if [ -f "${osxKvmRepo}/''${OVMF_FILE}" ]; then
        echo "Seeding writable OVMF NVRAM (''${OVMF_FILE}) …"
        ${pkgs.coreutils}/bin/cp -f "${osxKvmRepo}/''${OVMF_FILE}" "''${DATA_DIR}/''${OVMF_FILE}"
        ${pkgs.coreutils}/bin/chmod u+w "''${DATA_DIR}/''${OVMF_FILE}"
      else
        echo "No ''${OVMF_FILE} in repo — set resolution in OVMF menu at boot if needed" >&2
      fi
      echo "OpenCore: copy from flake input → staging, patch Resolution=''${RES}, build qcow2 …"
      rm -rf "''${STAGING}"
      ${pkgs.coreutils}/bin/cp -a "${osxKvmRepo}/OpenCore" "''${STAGING}"
      ${pkgs.coreutils}/bin/chmod -R u+w "''${STAGING}"

      ${pkgs.python3}/bin/python3 -c '
import plistlib
import sys

def set_resolution(obj, value):
    n = 0
    if isinstance(obj, dict):
        if "Resolution" in obj and isinstance(obj["Resolution"], str):
            obj["Resolution"] = value
            n += 1
        for v in obj.values():
            n += set_resolution(v, value)
    elif isinstance(obj, list):
        for item in obj:
            n += set_resolution(item, value)
    return n

path, res = sys.argv[1], sys.argv[2]
with open(path, "rb") as f:
    data = plistlib.load(f)
count = set_resolution(data, res)
if count == 0:
    sys.exit("No Resolution keys found in config.plist")
with open(path, "wb") as f:
    plistlib.dump(data, f)
print("Patched", count, "Resolution key(s) ->", res)
' "''${STAGING}/config.plist" "''${RES}"

      export PATH="${pkgs.lib.makeBinPath [ libguestfs pkgs.coreutils ]}:$PATH"
      export LIBGUESTFS_BACKEND=direct
      export TMPDIR="''${DATA_DIR}/tmp"
      mkdir -p "''${TMPDIR}"
      rm -f "''${STAGING}/OpenCore.qcow2"

      # opencore-image-ng.sh expects $BASE/../resources/OcBinaryData/Resources; run from STAGING
      # so $BASE is writable and ../resources is under DATA_DIR (not the read-only nix store).
      mkdir -p "''${DATA_DIR}/resources/OcBinaryData"
      if [ -d "${osxKvmRepo}/resources/OcBinaryData/Resources" ]; then
        ln -sfn "${osxKvmRepo}/resources/OcBinaryData/Resources" \
          "''${DATA_DIR}/resources/OcBinaryData/Resources"
      else
        echo "OcBinaryData submodule missing in flake input; using OpenCore/EFI/OC/Resources" >&2
        ln -sfn "''${STAGING}/EFI/OC/Resources" "''${DATA_DIR}/resources/OcBinaryData/Resources"
      fi
      ${pkgs.coreutils}/bin/cp "${osxKvmRepo}/OpenCore/opencore-image-ng.sh" "''${STAGING}/opencore-image-ng.sh"
      ${pkgs.coreutils}/bin/chmod +x "''${STAGING}/opencore-image-ng.sh"
      ${pkgs.gnused}/bin/sed -i 's/sudo rm -rf/rm -rf/' "''${STAGING}/opencore-image-ng.sh"
      cd "''${STAGING}"
      ${pkgs.bash}/bin/bash ./opencore-image-ng.sh \
        --cfg "''${STAGING}/config.plist" \
        --img "''${STAGING}/OpenCore.qcow2"

      rm -rf "''${DATA_DIR}/OpenCore"
      ${pkgs.coreutils}/bin/cp -a "''${STAGING}" "''${DATA_DIR}/OpenCore"
      rm -rf "''${STAGING}"
      echo "''${RES}" > "''${STAMP}"
    else
      echo "OpenCore already built for ''${RES} — skipping rebuild"
    fi

    ln -sfn "${osxKvmRepo}/OVMF_CODE_4M.fd" "''${DATA_DIR}/OVMF_CODE_4M.fd"
    echo "Ready in ''${DATA_DIR} (resolution ''${RES}, OVMF ''${OVMF_FILE})"
  '';

  osx-kvm-boot = pkgs.writeShellScriptBin "osx-kvm-boot" ''
    ${commonEnv}
    OVMF_FILE="${ovmfFile}"

    for f in BaseSystem.img mac_hdd_ng.img "''${OVMF_FILE}"; do
      if [ ! -e "''${DATA_DIR}/$f" ]; then
        echo "Missing ''${DATA_DIR}/$f — run osx-kvm-prepare first." >&2
        exit 1
      fi
    done

    if [ ! -f "''${DATA_DIR}/OpenCore/OpenCore.qcow2" ]; then
      echo "Missing OpenCore.qcow2 — run osx-kvm-prepare (resolution ${cfg.resolution})." >&2
      exit 1
    fi

    ln -sfn "${osxKvmRepo}/OVMF_CODE_4M.fd" "''${DATA_DIR}/OVMF_CODE_4M.fd"
    ${pkgs.coreutils}/bin/chmod u+w "''${DATA_DIR}/''${OVMF_FILE}"

    export PATH="${pkgs.lib.makeBinPath [ pkgs.qemu_kvm ]}:$PATH"
    ALLOCATED_RAM="''${OSX_KVM_RAM:-8192}"
    CPU_CORES="''${OSX_KVM_CORES:-4}"
    CPU_THREADS="''${OSX_KVM_THREADS:-8}"

    cd "''${DATA_DIR}"
    exec ${pkgs.qemu_kvm}/bin/qemu-system-x86_64 \
      -enable-kvm -m "''${ALLOCATED_RAM}" \
      -cpu Skylake-Client,-hle,-rtm,kvm=on,vendor=GenuineIntel,+invtsc,vmware-cpuid-freq=on,+ssse3,+sse4.2,+popcnt,+avx,+aes,+xsave,+xsaveopt,check \
      -machine q35 \
      -device qemu-xhci,id=xhci -device usb-kbd,bus=xhci.0 -device usb-tablet,bus=xhci.0 \
      -smp "''${CPU_THREADS}",cores="''${CPU_CORES}",sockets=1 \
      -device usb-ehci,id=ehci \
      -device isa-applesmc,osk="ourhardworkbythesewordsguardedpleasedontsteal(c)AppleComputerInc" \
      -drive if=pflash,format=raw,readonly=on,file="''${DATA_DIR}/OVMF_CODE_4M.fd" \
      -drive if=pflash,format=raw,file="''${DATA_DIR}/''${OVMF_FILE}" \
      -smbios type=2 \
      -device ich9-intel-hda -device hda-duplex \
      -device ich9-ahci,id=sata \
      -drive id=OpenCoreBoot,if=none,snapshot=on,format=qcow2,file="''${DATA_DIR}/OpenCore/OpenCore.qcow2" \
      -device ide-hd,bus=sata.2,drive=OpenCoreBoot \
      -device ide-hd,bus=sata.3,drive=InstallMedia \
      -drive id=InstallMedia,if=none,file="''${DATA_DIR}/BaseSystem.img",format=raw \
      -drive id=MacHDD,if=none,file="''${DATA_DIR}/mac_hdd_ng.img",format=qcow2 \
      -device ide-hd,bus=sata.4,drive=MacHDD \
      -netdev user,id=net0,hostfwd=tcp::10022-:22 \
      -device virtio-net-pci,netdev=net0,id=net0,mac=52:54:00:c9:18:27 \
      -monitor stdio -device vmware-svga \
      "$@"
  '';

  osx-kvm = pkgs.writeShellScriptBin "osx-kvm" ''
    ${osx-kvm-prepare}/bin/osx-kvm-prepare
    exec ${osx-kvm-boot}/bin/osx-kvm-boot "$@"
  '';

in
{
  options.programs.osx-kvm = {
    enable = lib.mkEnableOption "renatus777rr/OSX-KVM-updated macOS virtualization helpers";

    resolution = lib.mkOption {
      type = lib.types.str;
      default = "1920x1080";
      example = "1920x1080";
      description = ''
        Display resolution for OpenCore config.plist and matching OVMF_VARS-*.fd.
        Applied inside osx-kvm-prepare: copy OpenCore to a staging dir, patch plist,
        rebuild OpenCore.qcow2, then install under the VM data directory.
        Change this and re-run home-manager switch + osx-kvm-prepare to rebuild.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    home.packages = with pkgs; [
      qemu_kvm
      python3
      dmg2img
      p7zip
      gnumake
      gnused
      libguestfs-with-appliance
      tesseract
      tesseract5
      cdrtools
      osx-kvm-fetch
      osx-kvm-prepare
      osx-kvm-boot
      osx-kvm
    ];
  };
}
