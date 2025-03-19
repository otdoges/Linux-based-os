#!/bin/bash

# PrivaLinux OS Installer Launcher
# This script checks dependencies and launches the Python-based installer

set -e

# Check if running with root privileges
if [ "$(id -u)" -ne 0 ]; then
    echo "This installer must be run with root privileges."
    echo "Please run with sudo or as root."
    exit 1
fi

# Install required dependencies
echo "Checking and installing required dependencies..."
apt-get update
apt-get install -y \
    python3 \
    python3-pip \
    python3-pyqt5 \
    gparted \
    parted \
    rsync

# Get the directory of this script
SCRIPT_DIR="$(dirname "$0")"

# Make the Python installer executable
chmod +x "$SCRIPT_DIR/installer.py"

# Launch the installer
echo "Launching PrivaLinux OS Installer..."
exec python3 "$SCRIPT_DIR/installer.py"