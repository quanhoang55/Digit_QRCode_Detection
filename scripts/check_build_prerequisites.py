"""Fail early with actionable messages before running an expensive build."""

from __future__ import annotations

import platform
import shutil
import subprocess
import sys
from pathlib import Path


def main() -> int:
    project_root = Path(__file__).resolve().parents[1]
    errors: list[str] = []

    if sys.version_info < (3, 12):
        errors.append(f"Python 3.12 or newer is required (found {platform.python_version()}).")

    for command in ("uv",):
        if shutil.which(command) is None:
            errors.append(f"'{command}' is not installed or is not available on PATH.")
    node = shutil.which("node")
    node_version = "not found"
    if node is None:
        errors.append("Node.js 20 or newer is required to compile the frontend.")
    else:
        try:
            node_version = subprocess.check_output([node, "--version"], text=True).strip()
            if int(node_version.lstrip("v").split(".", 1)[0]) < 20:
                errors.append(f"Node.js 20 or newer is required (found {node_version}).")
        except (OSError, subprocess.SubprocessError, ValueError) as error:
            errors.append(f"Node.js could not run correctly: {error}")
    if shutil.which("bun") is None and shutil.which("npm") is None:
        errors.append("Install either Bun, or Node.js with npm, to build the frontend.")

    required = {
        "digit model": project_root / "backend" / "model" / "best.pt",
        "backend project": project_root / "backend" / "pyproject.toml",
        "frontend project": project_root / "frontend" / "package.json",
        "frontend entry point": project_root / "frontend" / "index.html",
    }
    for label, path in required.items():
        if not path.is_file():
            errors.append(f"Missing {label}: {path}")

    if errors:
        print("Build prerequisites failed:", file=sys.stderr)
        for error in errors:
            print(f"- {error}", file=sys.stderr)
        return 1

    model_size_mb = required["digit model"].stat().st_size / (1024 * 1024)
    print(f"Platform: {platform.system()} {platform.machine()}")
    print(f"Python: {platform.python_version()}")
    print(f"Node.js: {node_version}")
    print(f"Frontend package manager: {'bun' if shutil.which('bun') else 'npm'}")
    print(f"Model: {required['digit model']} ({model_size_mb:.1f} MiB)")
    print("Build prerequisites passed.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

