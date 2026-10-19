# -*- mode: python ; coding: utf-8 -*-

"""PyInstaller recipe for the portable Scale Detection application."""

import os
from pathlib import Path

from PyInstaller.utils.hooks import collect_all, copy_metadata


project_root = Path.cwd().resolve()
bundle_name = os.environ.get("SCALE_BUNDLE_NAME", "ScaleDetection")

required_files = (
    project_root / "frontend" / "dist" / "index.html",
    project_root / "backend" / "model" / "best.pt",
    project_root / "backend" / "src" / "backend" / "storage" / "schema.sql",
)
missing = [str(path) for path in required_files if not path.is_file()]
if missing:
    raise SystemExit("Build resources are missing:\n- " + "\n- ".join(missing))

ultralytics_data, ultralytics_binaries, ultralytics_hidden = collect_all("ultralytics")

datas = [
    (str(project_root / "frontend" / "dist"), "frontend_dist"),
    (str(project_root / "backend" / "model" / "best.pt"), "model"),
    (
        str(project_root / "backend" / "src" / "backend" / "storage" / "schema.sql"),
        "backend/storage",
    ),
    *ultralytics_data,
    *copy_metadata("ultralytics"),
    *copy_metadata("torch"),
]

hiddenimports = [
    *ultralytics_hidden,
    "uvicorn.logging",
    "uvicorn.loops.auto",
    "uvicorn.protocols.http.auto",
    "uvicorn.protocols.http.h11_impl",
    "uvicorn.protocols.websockets.auto",
    "uvicorn.protocols.websockets.websockets_impl",
    "uvicorn.lifespan.on",
]

analysis = Analysis(
    [str(project_root / "backend" / "src" / "backend" / "__main__.py")],
    pathex=[str(project_root / "backend" / "src")],
    binaries=ultralytics_binaries,
    datas=datas,
    hiddenimports=hiddenimports,
    hookspath=[],
    hooksconfig={},
    runtime_hooks=[],
    excludes=[],
    noarchive=False,
    optimize=0,
)
python_archive = PYZ(analysis.pure)

executable = EXE(
    python_archive,
    analysis.scripts,
    [],
    exclude_binaries=True,
    name="ScaleDetection",
    debug=False,
    bootloader_ignore_signals=False,
    strip=False,
    upx=False,
    console=True,
    disable_windowed_traceback=False,
    argv_emulation=False,
)

bundle = COLLECT(
    executable,
    analysis.binaries,
    analysis.datas,
    strip=False,
    upx=False,
    name=bundle_name,
)

