#!/bin/bash

# PrivaLinux OS Installer Script
# This script handles the installation process and drive formatting

set -e

# Function to display dialog boxes
show_dialog() {
    whiptail --title "PrivaLinux OS Installer" "$@"
}

# Welcome screen
show_dialog --msgbox "Welcome to PrivaLinux OS Installer\n\nThis installer will guide you through the installation process.\nWarning: This will erase the selected drive!" 12 60

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

# Let user select drive
SELECTED_DRIVE=$(whiptail --title "Select Installation Drive" \
    --menu "Choose the drive to install PrivaLinux OS:\n\nWARNING: Selected drive will be completely erased!" \
    20 70 10 "${DRIVE_OPTIONS[@]}" \
    3>&1 1>&2 2>&3)

# Confirm drive selection
whiptail --title "Confirm Drive Selection" \
    --yesno "Are you sure you want to install PrivaLinux OS on $SELECTED_DRIVE?\n\nThis will ERASE ALL DATA on this drive!" \
    12 60

# Create partition layout
echo "[+] Creating partition layout"
parted -s "$SELECTED_DRIVE" mklabel gpt
parted -s "$SELECTED_DRIVE" mkpart primary fat32 1MiB 512MiB
parted -s "$SELECTED_DRIVE" set 1 esp on
parted -s "$SELECTED_DRIVE" mkpart primary ext4 512MiB 100%

# Format partitions
echo "[+] Formatting partitions"
mkfs.fat -F32 "${SELECTED_DRIVE}1"
mkfs.ext4 "${SELECTED_DRIVE}2"

# Mount partitions
echo "[+] Mounting partitions"
mount "${SELECTED_DRIVE}2" /mnt
mkdir -p /mnt/boot/efi
mount "${SELECTED_DRIVE}1" /mnt/boot/efi

# Copy system files
echo "[+] Copying system files"
rsync -av /run/live/medium/casper/filesystem.squashfs/* /mnt/

# Install bootloader
echo "[+] Installing bootloader"
for dir in /dev /dev/pts /proc /sys /run; do
    mount -B $dir /mnt$dir
done
chroot /mnt grub-install --target=x86_64-efi --efi-directory=/boot/efi
chroot /mnt update-grub

# Configure Cinnamon desktop
echo "[+] Configuring Cinnamon desktop environment"
chroot /mnt apt-get update
chroot /mnt apt-get install -y cinnamon cinnamon-desktop-environment

# Set Cinnamon as default desktop
chroot /mnt /bin/bash -c 'echo "[Seat:*]\nuser-session=cinnamon" > /etc/lightdm/lightdm.conf.d/50-cinnamon.conf'

# Clean up
for dir in /dev/pts /dev /proc /sys /run; do
    umount /mnt$dir
done
umount /mnt/boot/efi
umount /mnt

show_dialog --msgbox "Installation Complete!\n\nPrivaLinux OS has been successfully installed.\nYou can now reboot your system." 12 60