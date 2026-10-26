@echo off
REM Doble clic o "iniciar.cmd" desde CMD. Ejecuta iniciar.ps1 sin cambiar la politica de scripts.
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0iniciar.ps1" %*
