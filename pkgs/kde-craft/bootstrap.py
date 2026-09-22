#!/usr/bin/env python3
"""Unattended CraftRoot bootstrap for the NixOS FHS wrapper.

Mirrors setup/CraftBootstrap.py from
https://invent.kde.org/packaging/craft but skips the interactive wizard
and forces linux-gcc-x86_64. Official CraftBootstrap.getABI() currently
leaves `compiler` unset on Linux, which would crash --use-defaults.
"""

from __future__ import annotations

import argparse
import os
import re
import shutil
import subprocess
import sys
import tempfile
import urllib.request
from pathlib import Path

BRANCH = "master"
ABI = "linux-gcc-x86_64"
REPO_URL = "https://files.kde.org/craft/Qt6/"

ARCHIVE_URLS = [
    f"https://invent.kde.org/packaging/craft/-/archive/{BRANCH}/craft-{BRANCH}.zip",
    "https://github.com/KDE/craft/archive/refs/heads/master.zip",
]


def die(msg: str, code: int = 1) -> None:
    print(f"craft-setup: {msg}", file=sys.stderr)
    raise SystemExit(code)


def set_settings_value(lines: list[str], section: str, key: str, value: str) -> None:
    re_key = re.compile(rf"^[\#;]?\s*{re.escape(key)}\s*=.*$", re.IGNORECASE)
    re_section = re.compile(r"^\[(.*)\]$")
    in_section = False
    for i, line in enumerate(lines):
        match = re_section.match(line)
        if match:
            in_section = match.group(1) == section
        elif in_section and re_key.match(line):
            lines[i] = f"{key} = {value}"
            return
    die(f"unable to locate [{section}] {key} in CraftSettings.ini.template")


def download_archive(dest: Path) -> None:
    dest.parent.mkdir(parents=True, exist_ok=True)
    last_error: Exception | None = None
    for url in ARCHIVE_URLS:
        print(f"craft-setup: downloading {url}")
        try:
            urllib.request.urlretrieve(url, dest)
            if dest.stat().st_size > 0:
                return
        except Exception as exc:  # noqa: BLE001 — try the next mirror
            last_error = exc
            print(f"craft-setup: download failed: {exc}")
    die(f"failed to download Craft sources ({last_error})")


def unpack_craft(archive: Path, prefix: Path) -> Path:
    tmp = Path(tempfile.mkdtemp(prefix="craft-unpack-", dir=str(prefix)))
    try:
        shutil.unpack_archive(archive, tmp)
        candidates = [p for p in tmp.iterdir() if p.is_dir()]
        if len(candidates) != 1:
            die(f"unexpected archive layout in {tmp}: {candidates}")
        target = prefix / "craft-tmp"
        if target.exists():
            shutil.rmtree(target)
        shutil.move(str(candidates[0]), target)
        return target
    finally:
        shutil.rmtree(tmp, ignore_errors=True)


def write_settings(craft_tmp: Path, prefix: Path) -> None:
    template = craft_tmp / "CraftSettings.ini.template"
    if not template.is_file():
        die(f"missing {template}")
    lines = template.read_text(encoding="utf-8").splitlines()
    # Prefer the FHS path so CraftSettings.ini does not pin a GC-able /nix/store
    # python. sys.executable is still the real store path even inside bwrap.
    if Path("/usr/bin/python3").exists():
        python_home = "/usr/bin"
    else:
        python_home = str(Path(sys.executable).resolve().parent)
    set_settings_value(lines, "Paths", "Python", python_home)
    set_settings_value(lines, "General", "ABI", ABI)
    set_settings_value(lines, "Compile", "MakeProgram", "make")
    set_settings_value(lines, "General", "KFHostToolingVersion", "6")
    set_settings_value(lines, "Packager", "RepositoryUrl", REPO_URL)
    etc = prefix / "etc"
    etc.mkdir(parents=True, exist_ok=True)
    (etc / "CraftSettings.ini").write_text("\n".join(lines) + "\n", encoding="utf-8")
    print(f"craft-setup: wrote {etc / 'CraftSettings.ini'}")
    print(f"craft-setup:   ABI    = {ABI}")
    print(f"craft-setup:   Python = {python_home}")


def prefix_is_reusable(prefix: Path) -> bool:
    if not prefix.exists():
        return True
    leftover = [p.name for p in prefix.iterdir() if p.name != "download"]
    return leftover == []


def reset_prefix(prefix: Path) -> None:
    if not prefix.exists():
        return
    for child in prefix.iterdir():
        if child.name == "download":
            continue
        if child.is_dir() and not child.is_symlink():
            shutil.rmtree(child)
        else:
            child.unlink()


def run_craft(craft_tmp: Path, args: list[str]) -> None:
    script = craft_tmp / "bin" / "craft.py"
    if not script.is_file():
        die(f"missing {script}")
    cmd = [sys.executable, str(script), *args]
    print(f"craft-setup: execute: {' '.join(cmd)}")
    if subprocess.run(cmd, check=False).returncode != 0:
        die("craft bootstrap failed — see output above")


def main() -> None:
    parser = argparse.ArgumentParser(description="Bootstrap a CraftRoot for NixOS")
    parser.add_argument(
        "--prefix",
        default=os.environ.get("CRAFT_ROOT", os.path.expanduser("~/CraftRoot")),
        help="Craft install root (default: $CRAFT_ROOT or ~/CraftRoot)",
    )
    parser.add_argument(
        "--force",
        action="store_true",
        help="Wipe an existing CraftRoot (keeps download/ cache)",
    )
    parser.add_argument(
        "--branch",
        default=BRANCH,
        help="Craft branch to fetch (default: master)",
    )
    args = parser.parse_args()

    prefix = Path(os.path.expanduser(args.prefix)).resolve()
    print(f"craft-setup: installing Craft into {prefix}")

    if (prefix / "craft" / "craftenv.sh").is_file() and not args.force:
        die(
            f"Craft already installed at {prefix}\n"
            "  re-run with --force to wipe and reinstall (download cache is kept)",
            code=0,
        )

    if args.force:
        print("craft-setup: --force: removing previous install (keeping download/)")
        reset_prefix(prefix)
    elif not prefix_is_reusable(prefix):
        leftover = ", ".join(sorted(p.name for p in prefix.iterdir() if p.name != "download"))
        die(
            f"{prefix} is not empty ({leftover}).\n"
            "  pass --force to wipe it, or set CRAFT_ROOT to a new directory"
        )

    prefix.mkdir(parents=True, exist_ok=True)
    archive = prefix / "download" / f"craft-{args.branch}.zip"
    if archive.exists() and args.force:
        archive.unlink()
    if not archive.exists():
        download_archive(archive)

    craft_tmp = unpack_craft(archive, prefix)
    write_settings(craft_tmp, prefix)
    run_craft(craft_tmp, ["craft"])

    if craft_tmp.exists():
        shutil.rmtree(craft_tmp)

    env = prefix / "craft" / "craftenv.sh"
    if not env.is_file():
        die(f"bootstrap finished but {env} is missing")

    print()
    print("craft-setup: complete")
    print(f"  CraftRoot: {prefix}")
    print("  Next: craft-shell   or   craft --search kate")


if __name__ == "__main__":
    main()
