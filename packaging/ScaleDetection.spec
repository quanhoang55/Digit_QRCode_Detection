# -*- mode: python ; coding: utf-8 -*-

from pathlib import Path

from PyInstaller.utils.hooks import collect_all, copy_metadata


project_root = Path.cwd()
ultralytics_data, ultralytics_binaries, ultralytics_hidden = collect_all("ultralytics")

datas = [
    (str(project_root / "frontend" / "dist"), "frontend_dist"),
    (str(project_root / "backend" / "model" / "best.pt"), "model"),
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

a = Analysis(
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
pyz = PYZ(a.pure)

exe = EXE(
    pyz,
    a.scripts,
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

coll = COLLECT(
    exe,
    a.binaries,
    a.datas,
    strip=False,
    upx=False,
    name="ScaleDetection",
)
