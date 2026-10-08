@echo off
setlocal
cd /d "%~dp0"

if not exist "ScaleDetection.exe" (
  echo ScaleDetection.exe was not found in this folder.
  pause
  exit /b 1
)

start "Scale Detection Server" /D "%~dp0" "%~dp0ScaleDetection.exe"

powershell -NoProfile -ExecutionPolicy Bypass -Command ^
  "$url='http://127.0.0.1:8000'; $ready=$false;" ^
  "for($i=0; $i -lt 60; $i++){ try { Invoke-WebRequest -UseBasicParsing -Uri $url -TimeoutSec 1 | Out-Null; $ready=$true; break } catch { Start-Sleep -Milliseconds 500 } };" ^
  "if($ready){ Start-Process $url } else { Write-Host 'The server did not become ready. Check the Scale Detection Server window.' }"

endlocal
