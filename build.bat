@echo off
setlocal enabledelayedexpansion

echo PrivaLinux OS Build Script
echo ========================

:: Check if WSL is installed
wsl --status >nul 2>&1
if %errorlevel% neq 0 (
    echo Installing WSL...
    powershell -Command "Enable-WindowsOptionalFeature -Online -FeatureName Microsoft-Windows-Subsystem-Linux -NoRestart"
    echo Please restart your computer to complete WSL installation
    echo After restart, run this script again
    pause
    exit /b 1
)

:: Check if Ubuntu is installed in WSL
wsl -l | findstr "Ubuntu" >nul 2>&1
if %errorlevel% neq 0 (
    echo Installing Ubuntu in WSL...
    wsl --install -d Ubuntu
    echo Please wait for Ubuntu installation to complete
    echo After installation, set up your Ubuntu username and password
    echo Then run this script again
    pause
    exit /b 1
)

:: Check if git is installed in Windows
git --version >nul 2>&1
if %errorlevel% neq 0 (
    echo Installing Git...
    winget install --id Git.Git -e --source winget
    echo Please restart the script after Git installation
    pause
    exit /b 1
)

:: Check if repository exists, if not clone it
if not exist "%~dp0.git" (
    echo Cloning PrivaLinux repository...
    git clone https://github.com/otdoges/Linux-based-os.git .
)

:: Install required packages in Ubuntu
echo Installing required packages in Ubuntu...
wsl -d Ubuntu -e bash -c "sudo apt-get update && sudo apt-get install -y squashfs-tools xorriso isolinux genisoimage rsync wget zenity"

:: Convert Windows path to WSL path and run build script
echo Starting build process...
set "WIN_PATH=%~dp0"
set "WSL_PATH=/mnt/%WIN_PATH::=%"
set "WSL_PATH=!WSL_PATH:\=/!"

wsl -d Ubuntu -e bash -c "cd '%WSL_PATH%' && chmod +x scripts/build_iso.sh && sudo ./scripts/build_iso.sh"

echo Build process completed!
echo Check the output directory for the ISO file
pause