# PrivaLinux OS Build Script for Windows
# This script creates a custom Linux distribution ISO using WSL

# Configuration
$ErrorActionPreference = "Stop"
$BASE_DISTRO = "linuxmint"
$BASE_VERSION = "21"
$OUTPUT_NAME = "privalinux-os"
$OUTPUT_VERSION = "1.0"
$WORK_DIR = "./build"
$OUTPUT_DIR = "./output"
$CONFIG_DIR = "../config"
$PACKAGES_DIR = "../packages"
$BRANDING_DIR = "../branding"

# Check if WSL is installed
function Check-WSL {
    try {
        $wslCheck = wsl --status
        if ($LASTEXITCODE -ne 0) {
            throw "WSL is not properly installed"
        }
    } catch {
        Write-Host "[!] WSL is not installed. Please install WSL by running:"
        Write-Host "    wsl --install"
        Write-Host "Then restart your computer and run this script again."
        exit 1
    }
}

# Check if Ubuntu/Linux Mint is installed in WSL
function Check-WSL-Distro {
    $distros = wsl --list
    if (-not ($distros -match "Ubuntu")) {
        Write-Host "[!] Ubuntu not found in WSL. Installing Ubuntu..."
        wsl --install -d Ubuntu
        Write-Host "[+] Please wait for Ubuntu installation to complete and set up your user account"
        Write-Host "    Then run this script again."
        exit 1
    }
}

# Create necessary directories
function Create-Directories {
    New-Item -ItemType Directory -Force -Path $WORK_DIR | Out-Null
    New-Item -ItemType Directory -Force -Path $OUTPUT_DIR | Out-Null
    Write-Host "[+] Created working directories"
}

# Install required packages in WSL
function Install-Requirements {
    Write-Host "[+] Installing required packages in WSL"
    wsl bash -c "sudo apt-get update && sudo apt-get install -y squashfs-tools xorriso isolinux genisoimage rsync wget zenity"
}

# Main build process
function Start-Build {
    Write-Host "[+] Starting PrivaLinux OS build process"
    
    # Convert Windows paths to WSL paths
    $wslWorkDir = wsl wslpath -u "$((Get-Location).Path)/$WORK_DIR"
    $wslOutputDir = wsl wslpath -u "$((Get-Location).Path)/$OUTPUT_DIR"
    
    # Download ISO using WSL
    Write-Host "[+] Downloading base distribution ISO"
    if ($BASE_DISTRO -eq "ubuntu") {
        $isoUrl = "https://releases.ubuntu.com/$BASE_VERSION/ubuntu-$BASE_VERSION-desktop-amd64.iso"
    } else {
        $isoUrl = "https://mirrors.edge.kernel.org/linuxmint/stable/21/linuxmint-21-cinnamon-64bit.iso"
    }
    wsl bash -c "wget -c '$isoUrl' -O '$wslWorkDir/base.iso'"
    
    # Run the Linux build process in WSL
    Write-Host "[+] Running build process in WSL environment"
    wsl bash -c "cd '$((Get-Location).Path)' && sudo bash ./scripts/build_iso.sh"
}

# Main execution
try {
    Write-Host "[+] PrivaLinux OS Windows Build Script"
    Check-WSL
    Check-WSL-Distro
    Create-Directories
    Install-Requirements
    Start-Build
    Write-Host "[+] Build process completed successfully"
    Write-Host "[+] ISO file can be found in the $OUTPUT_DIR directory"
} catch {
    Write-Host "[!] Error: $($_.Exception.Message)"
    exit 1
}