@echo off
setlocal
cd /d "%~dp0"

if not exist "ScaleDetection.exe" (
  echo ERROR: ScaleDetection.exe was not found in this folder.
  echo Keep run.bat beside ScaleDetection.exe and the _internal folder.
  pause
  exit /b 1
)

start "Scale Detection Server" /D "%~dp0" "%~dp0ScaleDetection.exe"

powershell -NoProfile -ExecutionPolicy Bypass -Command ^
  "$url='http://127.0.0.1:8000'; $health=$url + '/health'; $ready=$false;" ^
  "for($i=0; $i -lt 120; $i++){ try { Invoke-WebRequest -UseBasicParsing -Uri $health -TimeoutSec 1 | Out-Null; $ready=$true; break } catch { Start-Sleep -Milliseconds 500 } };" ^
  "if($ready){ Start-Process $url } else { Write-Host 'The server did not become ready. Check the Scale Detection Server window.'; Read-Host 'Press Enter to close' }"

endlocal

