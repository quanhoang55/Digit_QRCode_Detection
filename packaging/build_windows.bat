@echo off
setlocal
cd /d "%~dp0\.."

if not exist "backend\model\best.pt" (
  echo Missing backend\model\best.pt
  exit /b 1
)

call npm --prefix frontend install || exit /b 1
call npm --prefix frontend run build || exit /b 1
uv run --project backend --with pyinstaller pyinstaller --noconfirm --clean packaging\ScaleDetection.spec || exit /b 1

copy /Y "packaging\run.bat" "dist\ScaleDetection\run.bat" >nul
copy /Y "packaging\.env.portable" "dist\ScaleDetection\.env" >nul

echo.
echo Portable Windows folder created at dist\ScaleDetection
echo Send the entire ScaleDetection folder. The recipient runs run.bat.
endlocal
