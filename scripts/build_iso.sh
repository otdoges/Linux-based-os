#!/bin/bash

# PrivaLinux OS Build Script
# This script creates a custom Linux distribution ISO based on Ubuntu/Linux Mint

set -e

# Configuration
BASE_DISTRO="ubuntu"
BASE_VERSION="22.04"
OUTPUT_NAME="privalinux-os"
OUTPUT_VERSION="1.0"
WORK_DIR="./build"
OUTPUT_DIR="./output"
CONFIG_DIR="../config"
PACKAGES_DIR="../packages"
BRANDING_DIR="../branding"

# Create necessary directories
mkdir -p "$WORK_DIR"
mkdir -p "$OUTPUT_DIR"

echo "[+] Starting PrivaLinux OS build process"

# Step 1: Download base ISO
echo "[+] Downloading base distribution ISO"
if [ "$BASE_DISTRO" == "ubuntu" ]; then
    wget -c "https://releases.ubuntu.com/$BASE_VERSION/ubuntu-$BASE_VERSION-desktop-amd64.iso" -O "$WORK_DIR/base.iso"
elif [ "$BASE_DISTRO" == "linuxmint" ]; then
    # Replace with actual Linux Mint download URL
    wget -c "https://mirrors.edge.kernel.org/linuxmint/stable/21/linuxmint-21-cinnamon-64bit.iso" -O "$WORK_DIR/base.iso"
else
    echo "[!] Unsupported base distribution"
    exit 1
fi

# Step 2: Extract ISO contents
echo "[+] Extracting ISO contents"
mkdir -p "$WORK_DIR/iso_extract"
mkdir -p "$WORK_DIR/iso_mount"

# Mount the ISO
mount -o loop "$WORK_DIR/base.iso" "$WORK_DIR/iso_mount"

# Copy contents to working directory
rsync -a "$WORK_DIR/iso_mount/" "$WORK_DIR/iso_extract/"

# Unmount ISO
umount "$WORK_DIR/iso_mount"

# Step 3: Customize the distribution
echo "[+] Customizing distribution"

# Create chroot environment
mkdir -p "$WORK_DIR/chroot"

# Extract squashfs filesystem
unsquashfs -d "$WORK_DIR/chroot" "$WORK_DIR/iso_extract/casper/filesystem.squashfs"

# Prepare chroot environment
mount --bind /dev "$WORK_DIR/chroot/dev"
mount --bind /run "$WORK_DIR/chroot/run"
mount --bind /proc "$WORK_DIR/chroot/proc"
mount --bind /sys "$WORK_DIR/chroot/sys"

# Copy package list and configuration files
cp "$PACKAGES_DIR/package_list.conf" "$WORK_DIR/chroot/tmp/"
cp "$CONFIG_DIR/privacy_settings.conf" "$WORK_DIR/chroot/tmp/"

# Install packages and apply configurations inside chroot
chroot "$WORK_DIR/chroot" /bin/bash -c "
    # Update package lists
    apt-get update
    
    # Install packages from package list
    grep -v '^#' /tmp/package_list.conf | xargs apt-get install -y
    
    # Apply privacy configurations
    # This would be implemented with actual configuration commands
    echo 'Applying privacy configurations from /tmp/privacy_settings.conf'
    
    # Clean up
    apt-get clean
    rm -rf /tmp/* /var/tmp/*
    rm -rf /var/lib/apt/lists/*
    rm -rf /var/cache/apt/archives/*.deb
"

# Unmount chroot bindings
umount "$WORK_DIR/chroot/dev"
umount "$WORK_DIR/chroot/run"
umount "$WORK_DIR/chroot/proc"
umount "$WORK_DIR/chroot/sys"

# Step 4: Apply branding
echo "[+] Applying PrivaLinux branding"
cp -r "$BRANDING_DIR/"* "$WORK_DIR/iso_extract/"

# Step 5: Rebuild squashfs filesystem
echo "[+] Rebuilding filesystem"
mksquashfs "$WORK_DIR/chroot" "$WORK_DIR/iso_extract/casper/filesystem.squashfs" -comp xz

# Step 6: Update ISO metadata
echo "[+] Updating ISO metadata"
cd "$WORK_DIR/iso_extract"

# Update md5sums
find . -type f -not -path "./md5sum.txt" -not -path "./isolinux/*" | sort | xargs md5sum > md5sum.txt

# Step 7: Build the ISO
echo "[+] Building PrivaLinux OS ISO"
xorriso -as mkisofs \
    -isohybrid-mbr /usr/lib/ISOLINUX/isohdpfx.bin \
    -c isolinux/boot.cat \
    -b isolinux/isolinux.bin \
    -no-emul-boot \
    -boot-load-size 4 \
    -boot-info-table \
    -eltorito-alt-boot \
    -e boot/grub/efi.img \
    -no-emul-boot \
    -isohybrid-gpt-basdat \
    -volid "$OUTPUT_NAME-$OUTPUT_VERSION" \
    -o "$OUTPUT_DIR/$OUTPUT_NAME-$OUTPUT_VERSION.iso" \
    .

echo "[+] Build complete: $OUTPUT_DIR/$OUTPUT_NAME-$OUTPUT_VERSION.iso"

# Clean up
echo "[+] Cleaning up build environment"
rm -rf "$WORK_DIR"

echo "[+] PrivaLinux OS build process completed successfully"