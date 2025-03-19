#!/bin/bash

# PrivaLinux OS Installer Script
# This script is a wrapper that launches the GUI installer
# For advanced installation options, use the GUI installer directly

set -e

# Check if running with root privileges
if [ "$(id -u)" -ne 0 ]; then
    echo "This installer must be run with root privileges."
    exit 1
fi

# Check if zenity is installed
if ! command -v zenity &> /dev/null; then
    echo "Installing zenity for GUI support..."
    apt-get update
    apt-get install -y zenity gparted
fi

# Check if GUI installer exists
GUI_INSTALLER="$(dirname "$0")/gui_installer.sh"
if [ ! -f "$GUI_INSTALLER" ]; then
    echo "Error: GUI installer not found at $GUI_INSTALLER"
    exit 1
fi

# Make GUI installer executable
chmod +x "$GUI_INSTALLER"

# Launch GUI installer
echo "Launching PrivaLinux OS GUI Installer..."
exec "$GUI_INSTALLER"