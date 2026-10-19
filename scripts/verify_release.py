"""Verify that a PyInstaller onedir release contains all runtime resources."""

from __future__ import annotations

import argparse
import os
from pathlib import Path


def directory_size(path: Path) -> int:
    return sum(item.stat().st_size for item in path.rglob("*") if item.is_file())


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("release", type=Path)
    parser.add_argument("--platform", choices=("windows", "macos"), required=True)
    args = parser.parse_args()

    release = args.release.resolve()
    internal = release / "_internal"
    executable = release / ("ScaleDetection.exe" if args.platform == "windows" else "ScaleDetection")
    launcher = release / ("run.bat" if args.platform == "windows" else "run.command")
    required = (
        executable,
        launcher,
        release / ".env",
        internal / "model" / "best.pt",
        internal / "frontend_dist" / "index.html",
        internal / "backend" / "storage" / "schema.sql",
    )
    missing = [str(path) for path in required if not path.is_file()]
    if missing:
        print("Release verification failed. Missing files:")
        for path in missing:
            print(f"- {path}")
        return 1

    if args.platform == "macos" and not os.access(executable, os.X_OK):
        print(f"Release verification failed: {executable} is not executable.")
        return 1

    size_mb = directory_size(release) / (1024 * 1024)
    print(f"Release verification passed: {release} ({size_mb:.1f} MiB)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

