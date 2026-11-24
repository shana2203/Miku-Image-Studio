@echo off
cd /d "%~dp0"
powershell -NoProfile -ExecutionPolicy Bypass -File Preparar.ps1
if errorlevel 1 (
 echo Instalacion incompleta. Revise el error y vuelva a ejecutar.
 pause
 exit /b 1
)
start "" "Miku Image Studio.exe"
