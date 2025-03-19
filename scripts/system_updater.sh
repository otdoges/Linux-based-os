#!/bin/bash

# PrivaLinux System Updater
# This script handles system updates with secure verification and user prompts

# Configuration
UPDATE_SERVER="https://privalinux.org/updates"
UPDATE_MANIFEST="${UPDATE_SERVER}/manifest.json"
BACKUP_DIR="/var/backups/privalinux"
LOG_FILE="/var/log/privalinux-updater.log"

# Function to log messages
log_message() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

# Function to create system backup
create_backup() {
    log_message "Creating system backup..."
    mkdir -p "$BACKUP_DIR"
    timestamp=$(date '+%Y%m%d_%H%M%S')
    tar czf "${BACKUP_DIR}/system_backup_${timestamp}.tar.gz" /etc /boot/grub
    if [ $? -eq 0 ]; then
        log_message "Backup created successfully"
        return 0
    else
        log_message "Backup creation failed"
        return 1
    fi
}

# Function to check for updates
check_updates() {
    log_message "Checking for system updates..."
    if ! curl -s -f "$UPDATE_MANIFEST" > /tmp/manifest.json; then
        zenity --error \
               --title="Update Error" \
               --text="Failed to connect to update server."
        return 1
    fi

    # Compare versions and create update list
    current_version=$(cat /etc/privalinux-version)
    available_version=$(jq -r '.version' /tmp/manifest.json)
    
    if [ "$current_version" = "$available_version" ]; then
        zenity --info \
               --title="System Up to Date" \
               --text="Your system is already up to date."
        return 1
    fi
    
    return 0
}

# Function to download updates
download_updates() {
    log_message "Downloading updates..."
    update_url=$(jq -r '.update_url' /tmp/manifest.json)
    
    # Download with progress bar
    (curl -L "$update_url" -o /tmp/update.tar.gz 2>/dev/null) | \
    zenity --progress \
           --title="Downloading Updates" \
           --text="Downloading system updates..." \
           --percentage=0 \
           --auto-close

    # Verify checksum
    expected_checksum=$(jq -r '.checksum' /tmp/manifest.json)
    actual_checksum=$(sha256sum /tmp/update.tar.gz | cut -d' ' -f1)
    
    if [ "$expected_checksum" != "$actual_checksum" ]; then
        zenity --error \
               --title="Update Error" \
               --text="Update package verification failed."
        return 1
    fi
    
    return 0
}

# Function to install updates
install_updates() {
    log_message "Installing updates..."
    
    # Create backup before installation
    create_backup || return 1

    # Extract updates to temporary directory
    temp_dir=$(mktemp -d)
    tar xzf /tmp/update.tar.gz -C "$temp_dir"
    
    # Run update installation script
    if [ -f "$temp_dir/install.sh" ]; then
        chmod +x "$temp_dir/install.sh"
        if ! "$temp_dir/install.sh"; then
            zenity --error \
                   --title="Installation Failed" \
                   --text="Update installation failed. System will be restored from backup."
            restore_backup
            return 1
        fi
    fi

    # Update system version
    new_version=$(jq -r '.version' /tmp/manifest.json)
    echo "$new_version" > /etc/privalinux-version
    
    # Cleanup
    rm -rf "$temp_dir" /tmp/update.tar.gz /tmp/manifest.json
    
    zenity --info \
           --title="Update Complete" \
           --text="System has been successfully updated to version $new_version.
A restart may be required for changes to take effect."
    
    # Prompt for restart
    if zenity --question \
             --title="Restart Required" \
             --text="Would you like to restart your system now?"; then
        log_message "User initiated restart after update"
        systemctl reboot
    fi
}

# Main update process
main() {
    # Check if running as root
    if [ "$(id -u)" != "0" ]; then
        zenity --error \
               --title="Permission Error" \
               --text="This updater must be run as root."
        exit 1
    fi

    # Create log directory if it doesn't exist
    mkdir -p "$(dirname "$LOG_FILE")"

    # Check for updates
    if check_updates; then
        if zenity --question \
                 --title="Updates Available" \
                 --text="System updates are available. Would you like to install them now?"; then
            # Download and install updates
            if download_updates; then
                install_updates
            fi
        fi
    fi
}

# Run main function
main