# Portable one-click builds

The application is distributed as one folder per operating system. Reviewers do not need Python, Node.js, `uv`, or the source repository. They keep the complete folder together and launch `run.bat` on Windows or `run.command` on macOS.

PyInstaller is not a cross-compiler. Build the Windows folder on Windows and the macOS folder on macOS. A Windows build cannot run on macOS, and a macOS build cannot run on Windows.

## What the packaged application contains

- The Python interpreter and backend dependencies
- FastAPI/Uvicorn
- PyTorch, Ultralytics, and OpenCV
- `model/best.pt`
- The compiled React application
- A portable `.env`
- A one-click launcher

The packaged model and frontend are read-only bundle resources. Writable records are created beside the executable at `data/measurements.csv`. This avoids writing into PyInstaller's internal or temporary extraction directory.

## Build for Windows

The build computer needs Git, Python 3.12, Node.js/npm, and `uv`. From Command Prompt at the repository root, run:

```cmd
packaging\build_windows.bat
```

The script builds React first and then runs the equivalent PyInstaller command:

```cmd
uv run --project backend --with pyinstaller pyinstaller --noconfirm --clean packaging\ScaleDetection.spec
```

The output is:

```text
dist\ScaleDetection\
├── ScaleDetection.exe
├── run.bat
├── .env
└── _internal\
```

Send the entire `dist\ScaleDetection` folder, preferably as a ZIP file. The recipient extracts it and double-clicks `run.bat`. The launcher starts the backend, waits for the HTTP server, and opens `http://127.0.0.1:8000` in the default browser.

Do not use PyInstaller `--onefile` for this application. The model, Torch libraries, and frontend are large, and one-file mode extracts them to a temporary directory on every launch. The provided `onedir` build starts faster and keeps writable data in a predictable location.

## Build for macOS

On a macOS build computer, run:

```sh
chmod +x packaging/build_macos.sh
./packaging/build_macos.sh
```

The output is:

```text
dist/ScaleDetection/
├── ScaleDetection
├── run.command
├── .env
└── _internal/
```

Send the complete folder as a ZIP created on macOS so executable permissions are retained. The recipient double-clicks `run.command`.

Unsigned macOS executables can be stopped by Gatekeeper. For internal testing, the recipient can right-click `run.command`, choose **Open**, and confirm once. For client distribution without that warning, sign and notarize the executable with an Apple Developer certificate.

## Portable configuration

The build copies `packaging/.env.portable` beside the executable. Its important values are:

```env
MODEL_PATH=model/best.pt
CAMERA_SOURCE=0
STORAGE_ENABLE=true
STORAGE_TYPE=csv
CSV_PATH=data/measurements.csv
HOST=127.0.0.1
PORT=8000
```

The recipient may edit this `.env` to choose a different USB camera index or a network-camera URL. `CAMERA_SOURCE=0` normally opens the first available camera.

After a successful Save operation, records appear here:

```text
dist/ScaleDetection/data/measurements.csv
```

Keep the CSV closed in Excel while saving on Windows because Excel may lock the file.

## Updating a portable build

After changing frontend code, backend code, or the model, run the platform build script again. Always distribute the newly generated complete folder; do not copy only the executable because `_internal`, the frontend, and model are required.
