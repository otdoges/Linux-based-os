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

:: Create necessary directories in WSL
wsl -d Ubuntu -e bash -c "cd '%WSL_PATH%' && mkdir -p build/iso_extract build/iso_mount build/chroot output"

:: Download and extract base ISO
echo Downloading and extracting base ISO...
wsl -d Ubuntu -e bash -c "cd '%WSL_PATH%' && \
    if [ ! -f build/base.iso ]; then \
        wget -c https://mirrors.edge.kernel.org/linuxmint/stable/21/linuxmint-21-cinnamon-64bit.iso -O build/base.iso; \
    fi && \
    sudo mount -o loop build/base.iso build/iso_mount && \
    sudo rsync -a build/iso_mount/ build/iso_extract/ && \
    sudo umount build/iso_mount"

:: Apply customizations
echo Applying PrivaLinux customizations...
wsl -d Ubuntu -e bash -c "cd '%WSL_PATH%' && \
    sudo cp -r config/* build/iso_extract/preseed/ && \
    sudo cp -r branding/* build/iso_extract/isolinux/ && \
    sudo cp -r packages/package_list.conf build/iso_extract/preseed/"

:: Generate new ISO
echo Generating final ISO...
wsl -d Ubuntu -e bash -c "cd '%WSL_PATH%' && \
    sudo genisoimage -o output/privalinux-1.0.iso -b isolinux/isolinux.bin \
    -c isolinux/boot.cat -no-emul-boot -boot-load-size 4 -boot-info-table \
    -V 'PrivaLinux 1.0' -cache-inodes -r -J -l build/iso_extract"

echo Build process completed!
echo The ISO file has been created in the output directory
pause