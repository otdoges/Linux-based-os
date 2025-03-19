#!/bin/bash

# PrivaLinux OS Desktop Configuration Script
# This script configures desktop environment, themes, and animations

set -e

echo "[+] Configuring desktop environment for PrivaLinux OS"

# Create theme directory
mkdir -p /usr/share/themes/PrivaLinux
cp -r /etc/skel/.themes/PrivaLinux/* /usr/share/themes/PrivaLinux/

# Install required packages
apt-get install -y gnome-tweaks dconf-editor

# Copy GTK theme
mkdir -p /usr/share/themes/PrivaLinux/gtk-3.0
cp /etc/skel/config/gtk-theme.css /usr/share/themes/PrivaLinux/gtk-3.0/gtk.css

# Configure desktop animations
gsettings set org.gnome.desktop.interface gtk-theme 'PrivaLinux'
gsettings set org.gnome.desktop.wm.preferences theme 'PrivaLinux'

# Enable animations
gsettings set org.gnome.desktop.interface enable-animations true

# Configure window animations
gsettings set org.gnome.mutter center-new-windows true
gsettings set org.gnome.mutter attach-modal-dialogs true

# Set workspace animation speed
gsettings set org.gnome.mutter workspaces-only-on-primary true
gsettings set org.gnome.shell.window-switcher current-workspace-only true

# Configure desktop appearance
gsettings set org.gnome.desktop.interface cursor-theme 'Adwaita'
gsettings set org.gnome.desktop.interface icon-theme 'Mint-Y'
gsettings set org.gnome.desktop.interface font-name 'Ubuntu 11'
gsettings set org.gnome.desktop.interface document-font-name 'Sans 11'
gsettings set org.gnome.desktop.interface monospace-font-name 'Ubuntu Mono 13'

# Configure window controls
gsettings set org.gnome.desktop.wm.preferences button-layout 'close,minimize,maximize:'
gsettings set org.gnome.desktop.wm.preferences resize-with-right-button true

# Set dark theme
gsettings set org.gnome.desktop.interface color-scheme 'prefer-dark'

# Configure dock
gsettings set org.gnome.shell.extensions.dash-to-dock extend-height false
gsettings set org.gnome.shell.extensions.dash-to-dock dock-position 'BOTTOM'
gsettings set org.gnome.shell.extensions.dash-to-dock transparency-mode 'DYNAMIC'
gsettings set org.gnome.shell.extensions.dash-to-dock unity-backlit-items true

# Configure overview
gsettings set org.gnome.shell.app-switcher current-workspace-only true
gsettings set org.gnome.mutter dynamic-workspaces true
gsettings set org.gnome.desktop.wm.preferences num-workspaces 4

# Enable desktop icons
gsettings set org.gnome.desktop.background show-desktop-icons true

# Configure power settings
gsettings set org.gnome.settings-daemon.plugins.power sleep-inactive-ac-timeout 3600
gsettings set org.gnome.settings-daemon.plugins.power sleep-inactive-battery-timeout 1800

# Set default terminal profile
gsettings set org.gnome.Terminal.ProfilesList default 'b1dcc9dd-5262-4d8d-a863-c897e6d979b9'
dconf write /org/gnome/terminal/legacy/profiles:/:b1dcc9dd-5262-4d8d-a863-c897e6d979b9/background-color "'rgb(40,40,40)'"
dconf write /org/gnome/terminal/legacy/profiles:/:b1dcc9dd-5262-4d8d-a863-c897e6d979b9/foreground-color "'rgb(208,207,204)'"
dconf write /org/gnome/terminal/legacy/profiles:/:b1dcc9dd-5262-4d8d-a863-c897e6d979b9/use-transparent-background true
dconf write /org/gnome/terminal/legacy/profiles:/:b1dcc9dd-5262-4d8d-a863-c897e6d979b9/background-transparency-percent 15

# Create desktop shortcuts
mkdir -p /etc/skel/Desktop
cat > /etc/skel/Desktop/firefox.desktop << EOF
[Desktop Entry]
Version=1.0
Type=Application
Name=Firefox
Comment=Browse the World Wide Web
Exec=firefox %u
Icon=firefox
Terminal=false
Categories=Network;WebBrowser;
EOF

chmod +x /etc/skel/Desktop/firefox.desktop

echo "[+] Desktop configuration completed successfully"