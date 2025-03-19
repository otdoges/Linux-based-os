#!/bin/bash

# PrivaLinux OS Graphical Installer Script
# This script provides a GUI-based installation process with advanced partition management

set -e

# Function to display zenity dialog boxes
show_dialog() {
    zenity "$@"
}

# Check if running with root privileges
if [ "$(id -u)" -ne 0 ]; then
    show_dialog --error --title="PrivaLinux OS Installer" --text="This installer must be run with root privileges."
    exit 1
 fi

# Welcome screen
show_dialog --info --title="PrivaLinux OS Installer" \
    --text="Welcome to PrivaLinux OS Installer\n\nThis installer will guide you through the installation process." \
    --width=500 --height=200

# Get available drives
DRIVES=$(lsblk -d -n -p -o NAME,SIZE,MODEL | grep -v loop | grep -v sr0)

# Create drive selection options
DRIVE_OPTIONS=()
while read -r line; do
    NAME=$(echo "$line" | awk '{print $1}')
    SIZE=$(echo "$line" | awk '{print $2}')
    MODEL=$(echo "$line" | cut -d' ' -f3-)
    DRIVE_OPTIONS+=("$NAME" "$SIZE $MODEL")
done <<< "$DRIVES"

# Format drive options for zenity
ZENITY_DRIVE_OPTIONS=""
for ((i=0; i<${#DRIVE_OPTIONS[@]}; i+=2)); do
    ZENITY_DRIVE_OPTIONS+="${DRIVE_OPTIONS[i]}|${DRIVE_OPTIONS[i+1]}\n"
done

# Let user select drive
SELECTED_DRIVE=$(show_dialog --list --title="Select Installation Drive" \
    --text="Choose the drive to install PrivaLinux OS:\n\nWARNING: Selected drive will be completely erased!" \
    --column="Drive" --column="Details" --separator="|" --width=600 --height=400 \
    $(echo -e "$ZENITY_DRIVE_OPTIONS") | cut -d'|' -f1)

# Exit if no drive selected
if [ -z "$SELECTED_DRIVE" ]; then
    show_dialog --error --title="PrivaLinux OS Installer" --text="No drive selected. Installation aborted."
    exit 1
fi

# Confirm drive selection
show_dialog --question --title="Confirm Drive Selection" \
    --text="Are you sure you want to install PrivaLinux OS on $SELECTED_DRIVE?\n\nThis will ERASE ALL DATA on this drive!" \
    --width=500 --height=200

# Exit if not confirmed
if [ $? -ne 0 ]; then
    show_dialog --info --title="PrivaLinux OS Installer" --text="Installation aborted."
    exit 0
fi

# Ask if user wants to use automatic partitioning or manual partitioning
PARTITION_METHOD=$(show_dialog --list --title="Partition Method" \
    --text="How would you like to partition the drive?" \
    --column="Method" --column="Description" --width=600 --height=300 \
    "automatic" "Automatically create recommended partitions" \
    "manual" "Manually partition the drive using GParted")

# Handle partitioning based on user choice
if [ "$PARTITION_METHOD" = "manual" ]; then
    # Launch GParted for manual partitioning
    show_dialog --info --title="Manual Partitioning" \
        --text="GParted will now open for manual partitioning.\n\nPlease create at least:\n- An EFI partition (fat32, 512MB)\n- A root partition (ext4, remaining space)\n\nClick OK to continue." \
        --width=500 --height=300
    
    # Launch GParted
    gparted "$SELECTED_DRIVE"
    
    # After GParted closes, ask user to identify partitions
    PARTITIONS=$(lsblk -p -o NAME,SIZE,FSTYPE "$SELECTED_DRIVE" | grep -v "$SELECTED_DRIVE $")
    
    # Show partitions and ask user to select EFI partition
    EFI_PARTITION=$(show_dialog --list --title="Select EFI Partition" \
        --text="Select the EFI partition (should be formatted as fat32):" \
        --column="Partition" --column="Size" --column="Type" --width=600 --height=400 \
        $(echo "$PARTITIONS" | awk '{print $1 " " $2 " " $3}'))
    
    # Show partitions and ask user to select root partition
    ROOT_PARTITION=$(show_dialog --list --title="Select Root Partition" \
        --text="Select the root partition (should be formatted as ext4):" \
        --column="Partition" --column="Size" --column="Type" --width=600 --height=400 \
        $(echo "$PARTITIONS" | awk '{print $1 " " $2 " " $3}'))
    
    # Optional: Ask if user wants a separate home partition
    HOME_PARTITION=""
    if show_dialog --question --title="Home Partition" \
        --text="Did you create a separate home partition?" \
        --width=400 --height=200; then
        
        HOME_PARTITION=$(show_dialog --list --title="Select Home Partition" \
            --text="Select the home partition:" \
            --column="Partition" --column="Size" --column="Type" --width=600 --height=400 \
            $(echo "$PARTITIONS" | awk '{print $1 " " $2 " " $3}'))
    fi
else
    # Automatic partitioning
    show_dialog --info --title="Automatic Partitioning" \
        --text="The installer will now automatically partition the drive." \
        --width=500 --height=200
    
    # Create progress dialog
    (
    echo "10"; echo "# Creating partition table..."
    # Create partition layout
    parted -s "$SELECTED_DRIVE" mklabel gpt
    
    echo "20"; echo "# Creating EFI partition..."
    parted -s "$SELECTED_DRIVE" mkpart primary fat32 1MiB 512MiB
    parted -s "$SELECTED_DRIVE" set 1 esp on
    
    echo "30"; echo "# Creating root partition..."
    parted -s "$SELECTED_DRIVE" mkpart primary ext4 512MiB 100%
    
    echo "40"; echo "# Formatting EFI partition..."
    # Format partitions
    mkfs.fat -F32 "${SELECTED_DRIVE}1"
    
    echo "50"; echo "# Formatting root partition..."
    mkfs.ext4 "${SELECTED_DRIVE}2"
    
    # Set variables for installation
    EFI_PARTITION="${SELECTED_DRIVE}1"
    ROOT_PARTITION="${SELECTED_DRIVE}2"
    HOME_PARTITION=""
    
    echo "60"; echo "# Partitioning complete."
    ) | show_dialog --progress --title="Partitioning Drive" --text="Preparing drive for installation..." --percentage=0 --auto-close --width=500
fi

# Show installation progress
(
# Mount partitions
echo "10"; echo "# Mounting partitions..."
mount "$ROOT_PARTITION" /mnt
mkdir -p /mnt/boot/efi
mount "$EFI_PARTITION" /mnt/boot/efi

# Mount home partition if specified
if [ -n "$HOME_PARTITION" ]; then
    echo "15"; echo "# Mounting home partition..."
    mkdir -p /mnt/home
    mount "$HOME_PARTITION" /mnt/home
fi

# Copy system files
echo "20"; echo "# Copying system files (this may take a while)..."
rsync -av /run/live/medium/casper/filesystem.squashfs/* /mnt/

# Setup EFI directory structure and install bootloader
echo "60"; echo "# Setting up EFI and installing bootloader..."

# Create necessary EFI directories
mkdir -p /mnt/boot/efi/EFI/BOOT
mkdir -p /mnt/boot/efi/EFI/privalinux

# Mount virtual filesystems for chroot
for dir in /dev /dev/pts /proc /sys /run; do
    mount -B $dir /mnt$dir
done

# Install GRUB with UEFI support
chroot /mnt grub-install --target=x86_64-efi --efi-directory=/boot/efi --bootloader-id=privalinux --recheck
chroot /mnt grub-install --target=x86_64-efi --efi-directory=/boot/efi --removable --recheck

# Update GRUB configuration
chroot /mnt update-grub

# Copy GRUB EFI file as fallback bootloader
cp /mnt/boot/efi/EFI/privalinux/grubx64.efi /mnt/boot/efi/EFI/BOOT/BOOTX64.EFI

# Configure Cinnamon desktop
echo "80"; echo "# Configuring desktop environment..."
chroot /mnt apt-get update
chroot /mnt apt-get install -y cinnamon cinnamon-desktop-environment

# Set Cinnamon as default desktop
chroot /mnt /bin/bash -c 'echo "[Seat:*]\nuser-session=cinnamon" > /etc/lightdm/lightdm.conf.d/50-cinnamon.conf'

# Clean up
echo "90"; echo "# Cleaning up..."
for dir in /dev/pts /dev /proc /sys /run; do
    umount /mnt$dir
done
umount /mnt/boot/efi
if [ -n "$HOME_PARTITION" ]; then
    umount /mnt/home
fi
umount /mnt

echo "100"; echo "# Installation complete!"
) | show_dialog --progress --title="Installing PrivaLinux OS" --text="Installing system..." --percentage=0 --auto-close --width=500

# Load customization settings
source /tmp/customization.conf

# Browser selection
BROWSER_LIST=""
while IFS='|' read -r name package description; do
    BROWSER_LIST+="$package|$name - $description\n"
done <<< "$(echo "$DEFAULT_BROWSERS" | tr -d '[]')"

SELECTED_BROWSER=$(show_dialog --list --title="Browser Selection" \
    --text="Choose your default web browser:" \
    --column="Package" --column="Description" --separator="|" --width=600 --height=400 \
    $(echo -e "$BROWSER_LIST") | cut -d'|' -f1)

# VPN selection
VPN_LIST=""
while IFS='|' read -r name package description; do
    VPN_LIST+="$package|$name - $description\n"
done <<< "$(echo "$DEFAULT_VPNS" | tr -d '[]')"

SELECTED_VPN=$(show_dialog --list --title="VPN Selection" \
    --text="Choose your preferred VPN service:" \
    --column="Package" --column="Description" --separator="|" --width=600 --height=400 \
    $(echo -e "$VPN_LIST") | cut -d'|' -f1)

# Install selected packages
chroot /mnt apt-get install -y "$SELECTED_BROWSER" "$SELECTED_VPN" qbittorrent

# Configure DNS settings
cat > /mnt/etc/systemd/resolved.conf << EOF
[Resolve]
DNS=$DNS_PROVIDER $BACKUP_DNS_PROVIDER
DNSOverTLS=yes
EOF

# Show completion message
show_dialog --info --title="Installation Complete" \
    --text="PrivaLinux OS has been successfully installed.\n\nYou can now reboot your system." \
    --width=500 --height=200