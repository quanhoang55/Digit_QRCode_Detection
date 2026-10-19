# Portable one-click builds

The release is one self-contained folder per operating system. A reviewer extracts the ZIP and double-clicks `run.bat` on Windows or `run.command` on macOS. Their computer does not need Python, Node.js, npm, `uv`, or the source repository.

PyInstaller is not a cross-compiler. Run the Windows builder on Windows and the macOS builder on macOS. Build separately for each CPU architecture you intend to support.

## Contents of a release

- Embedded Python and all backend dependencies
- FastAPI/Uvicorn, PyTorch, Ultralytics, and OpenCV
- `backend/model/best.pt`
- The production React frontend
- The SQLite schema and CSV/SQLite storage code
- A portable `.env`
- A one-click launcher

The bundled model and frontend are read-only resources. Saved records are written beside the executable at `data/measurements.csv`, not inside PyInstaller's internal directory.

## Builder requirements

Only the computer that creates a release needs:

- Git
- `uv` (it installs/manages the project's Python 3.12 runtime)
- Node.js 20 or newer
- Bun (preferred because `bun.lock` is committed), or npm
- The tracked model at `backend/model/best.pt`

Before building, clone or pull the complete repository. Do not build from a source ZIP that omitted the `.pt` model.

## Build on Windows

Open Command Prompt at the repository root and run:

```cmd
scripts\build_windows.bat
```

The script checks prerequisites, installs frontend packages, builds React, bundles the backend, verifies required runtime files, and creates:

```text
release\ScaleDetection-Windows\
release\ScaleDetection-Windows.zip
```

Send `ScaleDetection-Windows.zip`. The recipient must extract it first, then open the extracted folder and double-click `run.bat`. Running directly inside the ZIP will not work.

The Windows artifact matches the architecture of the builder's Python installation. Use 64-bit Python on a normal 64-bit Windows client.

## Build on macOS

On the macOS build computer, run:

```sh
chmod +x scripts/build_macos.sh scripts/run.command
./scripts/build_macos.sh
```

On Apple Silicon the output is:

```text
release/ScaleDetection-macOS-arm64/
release/ScaleDetection-macOS-arm64.zip
```

An Intel Mac produces `ScaleDetection-macOS-x86_64`. Send the ZIP matching the recipient's Mac. The script uses macOS `ditto` so executable permissions survive the ZIP round trip.

An unsigned download may be blocked by Gatekeeper. For private testing, the recipient can right-click `run.command`, choose **Open**, and confirm once. For professional distribution, sign and notarize the application with an Apple Developer ID. Building on Apple Silicon does not automatically create an Intel or universal executable.

## Recipient instructions

1. Extract the complete ZIP.
2. Keep the executable, `_internal`, `.env`, launcher, and `data` folder together.
3. Connect the USB camera or start the network/virtual camera.
4. Double-click `run.bat` or `run.command`.
5. Allow camera access and local-network access if the operating system asks.
6. Keep the server window open while using the application.

The launcher waits for `http://127.0.0.1:8000/health` and then opens the application in the default browser.

## Portable configuration

The build copies `scripts/.env.portable` to `.env` beside the executable. Important defaults are:

```env
MODEL_PATH=model/best.pt
CAMERA_SOURCE=0
CAMERA_BACKEND=AUTO
STORAGE_ENABLE=true
STORAGE_TYPE=csv
CSV_PATH=data/measurements.csv
HOST=127.0.0.1
PORT=8000
```

Edit only the extracted release's `.env` when a client needs a different camera:

- Built-in/first USB camera: `CAMERA_SOURCE=0`
- Another camera: `CAMERA_SOURCE=1` or `2`
- OBS Virtual Camera on Windows: set `CAMERA_BACKEND=DSHOW`
- Force Windows Media Foundation: set `CAMERA_BACKEND=MSMF`
- Phone/IP camera: set `CAMERA_SOURCE` to its full HTTP or RTSP stream URL

Saved rows appear in `data/measurements.csv`. Keep that CSV closed in Excel while saving because Excel may lock the file on Windows.

## Build outputs and source control

Generated `build/`, `dist/`, and `release/` directories are ignored by Git. Re-run the platform build after changing the frontend, backend, dependencies, portable configuration, or model. Always distribute the new complete ZIP; copying only the executable is insufficient.

The old `packaging/build_windows.bat` and `packaging/build_macos.sh` paths remain as compatibility wrappers, but new documentation and automation should use `scripts/`.

## Production distribution

Unsigned executables commonly trigger Windows SmartScreen or macOS Gatekeeper. The build scripts create functional internal-test packages, but they do not provide trust certificates. For a polished client release:

- Sign the Windows executable with an Authenticode certificate.
- Sign and notarize the macOS build with an Apple Developer ID.
- Test each ZIP on a clean computer of the same OS and CPU architecture.
- Verify the intended physical camera index and permissions on that computer.
