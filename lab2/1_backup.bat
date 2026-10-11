@echo off
chcp 65001 >nul
rem Lab 2, variant 14: backup of the registry branches that will be changed
cd /d "%~dp0"
reg export "HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" backup_advanced.reg /y
reg export "HKLM\SOFTWARE\Classes\CLSID\{20D04FE0-3AEA-1069-A2D8-08002B30309D}\shell" backup_shell.reg /y
echo.
echo Gotovo. Esli vtoraya komanda napisala oshibku - eto normalno (razdela shell eshe net).
pause
