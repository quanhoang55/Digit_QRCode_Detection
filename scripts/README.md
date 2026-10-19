# Release scripts

These scripts create platform-native, one-folder releases. The client computer does not need Python, Node.js, npm, `uv`, or the source code.

- Windows builder: `scripts\build_windows.bat`
- macOS builder: `./scripts/build_macos.sh`
- PyInstaller recipe: `scripts/ScaleDetection.spec`
- Client launchers: `run.bat` and `run.command`
- Portable runtime settings: `.env.portable`
- Preflight and release checks: `check_build_prerequisites.py` and `verify_release.py`

Build Windows on Windows and macOS on macOS. PyInstaller cannot cross-compile. See `docs/PORTABLE_BUILD.md` for prerequisites, outputs, distribution, camera configuration, and signing notes.

