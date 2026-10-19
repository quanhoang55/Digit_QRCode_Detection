@echo off
setlocal EnableExtensions
cd /d "%~dp0\.."

echo [1/6] Checking build prerequisites...
where uv >nul 2>nul
if errorlevel 1 (
  echo ERROR: uv was not found. Install uv and reopen Command Prompt.
  exit /b 1
)
uv run --project backend --locked python scripts\check_build_prerequisites.py
if errorlevel 1 exit /b 1

where bun >nul 2>nul
if not errorlevel 1 (
  echo [2/6] Installing locked frontend dependencies with Bun...
  pushd frontend
  call bun install --frozen-lockfile
  if errorlevel 1 (popd & exit /b 1)
  echo [3/6] Building the React frontend...
  call bun run build
  if errorlevel 1 (popd & exit /b 1)
  popd
) else (
  echo [2/6] Installing frontend dependencies with npm...
  call npm --prefix frontend install
  if errorlevel 1 exit /b 1
  echo [3/6] Building the React frontend...
  call npm --prefix frontend run build
  if errorlevel 1 exit /b 1
)

echo [4/6] Bundling Python, dependencies, frontend, and model...
set "SCALE_BUNDLE_NAME=ScaleDetection-Windows"
uv run --project backend --locked --with pyinstaller pyinstaller --noconfirm --clean --distpath release --workpath build\pyinstaller\windows scripts\ScaleDetection.spec
if errorlevel 1 exit /b 1

set "RELEASE_DIR=%CD%\release\%SCALE_BUNDLE_NAME%"
set "RELEASE_ZIP=%CD%\release\%SCALE_BUNDLE_NAME%.zip"

echo [5/6] Adding portable configuration and launcher...
copy /Y "scripts\run.bat" "%RELEASE_DIR%\run.bat" >nul
copy /Y "scripts\.env.portable" "%RELEASE_DIR%\.env" >nul
if not exist "%RELEASE_DIR%\data" mkdir "%RELEASE_DIR%\data"
uv run --project backend --locked python scripts\verify_release.py "%RELEASE_DIR%" --platform windows
if errorlevel 1 exit /b 1

echo [6/6] Creating the client ZIP...
set "SCALE_RELEASE_DIR=%RELEASE_DIR%"
set "SCALE_RELEASE_ZIP=%RELEASE_ZIP%"
powershell -NoProfile -ExecutionPolicy Bypass -Command "if(Test-Path -LiteralPath $env:SCALE_RELEASE_ZIP){Remove-Item -LiteralPath $env:SCALE_RELEASE_ZIP -Force}; Compress-Archive -LiteralPath $env:SCALE_RELEASE_DIR -DestinationPath $env:SCALE_RELEASE_ZIP -CompressionLevel Optimal"
if errorlevel 1 exit /b 1

echo.
echo BUILD COMPLETE
echo Folder: %RELEASE_DIR%
echo Send:   %RELEASE_ZIP%
echo The recipient extracts the ZIP and double-clicks run.bat.
endlocal

