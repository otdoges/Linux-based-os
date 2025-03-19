#!/bin/bash

# PrivaLinux OS Build Script
# This script creates a custom Linux distribution ISO based on Ubuntu/Linux Mint

set -e

# Configuration
BASE_DISTRO="linuxmint"
BASE_VERSION="21"
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

# Step 1: Extract ISO contents
echo "[+] Extracting ISO contents"
mkdir -p "$WORK_DIR/iso_extract"
mkdir -p "$WORK_DIR/iso_mount"
mkdir -p "$WORK_DIR/squashfs"

# Mount the ISO
echo "[+] Mounting ISO"
mount -o loop "$WORK_DIR/base.iso" "$WORK_DIR/iso_mount"

# Copy contents to working directory
echo "[+] Copying ISO contents"
rsync -a "$WORK_DIR/iso_mount/" "$WORK_DIR/iso_extract/"

# Extract the squashfs filesystem
echo "[+] Extracting live filesystem"
unsquashfs -d "$WORK_DIR/squashfs" "$WORK_DIR/iso_mount/casper/filesystem.squashfs"

# Unmount ISO
umount "$WORK_DIR/iso_mount"

# Step 2: Customize the distribution
echo "[+] Customizing distribution"

# Mount virtual filesystems for chroot
echo "[+] Preparing chroot environment"
mount --bind /dev "$WORK_DIR/squashfs/dev"
mount --bind /dev/pts "$WORK_DIR/squashfs/dev/pts"
mount --bind /proc "$WORK_DIR/squashfs/proc"
mount --bind /sys "$WORK_DIR/squashfs/sys"

# Copy resolv.conf for network access in chroot
cp /etc/resolv.conf "$WORK_DIR/squashfs/etc/"

# Install additional packages and apply customizations in chroot
echo "[+] Installing packages and applying customizations"
chroot "$WORK_DIR/squashfs" /bin/bash -c "
    # Update package lists
    apt-get update

    # Install GRUB and required packages
    apt-get install -y grub-efi-amd64 grub-efi-amd64-signed shim-signed efibootmgr

    # Install packages from package list
    if [ -f /preseed/package_list.conf ]; then
        xargs apt-get install -y < /preseed/package_list.conf
    fi

    # Configure GRUB
    mkdir -p /boot/efi
    mkdir -p /boot/grub
    grub-install --target=x86_64-efi --efi-directory=/boot/efi --bootloader-id=privalinux --recheck

    # Configure GRUB settings
    echo 'GRUB_TIMEOUT=5' >> /etc/default/grub
    echo 'GRUB_DISTRIBUTOR=\"PrivaLinux\"' >> /etc/default/grub
    echo 'GRUB_ENABLE_CRYPTODISK=y' >> /etc/default/grub
    update-grub

    # Apply privacy settings
    if [ -f /preseed/privacy_settings.conf ]; then
        source /preseed/privacy_settings.conf
    fi

    # Apply performance settings
    if [ -f /preseed/performance_settings.conf ]; then
        source /preseed/performance_settings.conf
    fi

    # Clean up
    apt-get clean
    rm -rf /tmp/* ~/.bash_history
    rm /etc/resolv.conf
"

# Unmount virtual filesystems
umount "$WORK_DIR/squashfs/sys"
umount "$WORK_DIR/squashfs/proc"
umount "$WORK_DIR/squashfs/dev/pts"
umount "$WORK_DIR/squashfs/dev"

# Step 3: Create new squashfs
echo "[+] Creating new squashfs filesystem"
mksquashfs "$WORK_DIR/squashfs" "$WORK_DIR/iso_extract/casper/filesystem.squashfs" -comp xz -b 1M

# Step 4: Update ISO metadata
echo "[+] Updating ISO metadata"
cd "$WORK_DIR/iso_extract"
find . -type f -print0 | xargs -0 md5sum > md5sum.txt

# Step 5: Generate new ISO
echo "[+] Generating final ISO"
mkisofs -o "$OUTPUT_DIR/$OUTPUT_NAME-$OUTPUT_VERSION.iso" \
    -b isolinux/isolinux.bin -c isolinux/boot.cat \
    -no-emul-boot -boot-load-size 4 -boot-info-table \
    -V "$OUTPUT_NAME $OUTPUT_VERSION" -cache-inodes -r -J -l \
    "$WORK_DIR/iso_extract"

echo "[+] Build completed successfully"

# Extract squashfs filesystem with parallel processing
unsquashfs -processors $(nproc) -d "$WORK_DIR/chroot" "$WORK_DIR/iso_extract/casper/filesystem.squashfs"

# Prepare chroot environment
mount --bind /dev "$WORK_DIR/chroot/dev"
mount --bind /run "$WORK_DIR/chroot/run"
mount --bind /proc "$WORK_DIR/chroot/proc"
mount --bind /sys "$WORK_DIR/chroot/sys"

# Copy package list and configuration files
cp "$PACKAGES_DIR/package_list.conf" "$WORK_DIR/chroot/tmp/"
cp "$CONFIG_DIR/privacy_settings.conf" "$WORK_DIR/chroot/tmp/"

# Ask for installation type
INSTALL_TYPE=$(show_dialog --list --title="Installation Type" \
    --text="Choose your installation type:" \
    --column="Type" --column="Description" \
    "minimal" "Basic system with essential packages only" \
    "full" "Complete system with all packages" | tr -d '\n')

# Install packages and apply configurations inside chroot
chroot "$WORK_DIR/chroot" /bin/bash -c "
    # Update package lists
    apt-get update
    
    # Install packages based on selection
    if [ \"$INSTALL_TYPE\" = \"minimal\" ]; then
        grep -v '^#' /tmp/package_list.conf | grep '^base-system\|^systemd\|^network-manager\|^cinnamon\|^lightdm' | xargs apt-get install -y
    else
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

# Step 5: Rebuild squashfs filesystem with optimized compression
echo "[+] Rebuilding filesystem with optimized compression"
mksquashfs "$WORK_DIR/chroot" "$WORK_DIR/iso_extract/casper/filesystem.squashfs" \
    -comp zstd -Xcompression-level 19 \
    -processors $(nproc) \
    -wildcards \
    -e "usr/share/doc/*" \
    -e "usr/share/man/*" \
    -e "usr/share/help/*" \
    -e "usr/share/info/*" \
    -e "var/cache/apt/*" \
    -e "var/lib/apt/lists/*"

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