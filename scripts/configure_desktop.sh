#!/bin/bash

# PrivaLinux OS Desktop Configuration Script
# This script configures desktop environment, themes, animations and AI integration

set -e

echo "[+] Configuring desktop environment for PrivaLinux OS"

# Install required packages for enhanced desktop experience
apt-get install -y gnome-tweaks dconf-editor cinnamon-menu-editor plank ollama cairo-dock cairo-dock-plug-ins gparted synaptic

# Create theme directory
mkdir -p /usr/share/themes/PrivaLinux
cp -r /etc/skel/.themes/PrivaLinux/* /usr/share/themes/PrivaLinux/

# Configure Ollama AI service
systemctl enable --now ollama
ollama pull mistral

# Create AI assistant shortcut
cat > /etc/skel/Desktop/ai-assistant.desktop << EOF
[Desktop Entry]
Version=1.0
Type=Application
Name=AI Assistant
Comment=PrivaLinux AI Assistant powered by Ollama
Exec=gnome-terminal -- bash -c "echo 'Welcome to PrivaLinux AI Assistant' && ollama run mistral"
Icon=system-help
Terminal=false
Categories=Utility;AI;
EOF

chmod +x /etc/skel/Desktop/ai-assistant.desktop

# Copy GTK theme
mkdir -p /usr/share/themes/PrivaLinux/gtk-3.0
cp /etc/skel/config/gtk-theme.css /usr/share/themes/PrivaLinux/gtk-3.0/gtk.css

# Configure Cinnamon desktop settings
gsettings set org.cinnamon.theme name 'PrivaLinux'
gsettings set org.cinnamon.desktop.interface gtk-theme 'PrivaLinux'
gsettings set org.cinnamon.desktop.wm.preferences theme 'PrivaLinux'

# Enable animations and effects
gsettings set org.cinnamon enable-vfade true
gsettings set org.cinnamon enable-animations true
gsettings set org.cinnamon startup-animation true

# Configure window animations
gsettings set org.cinnamon.muffin tile-maximize true
gsettings set org.cinnamon.muffin edge-tiling true
gsettings set org.cinnamon.muffin resize-threshold 24

# Set workspace behavior
gsettings set org.cinnamon.desktop.wm.preferences num-workspaces 4
gsettings set org.cinnamon workspace-expo-view-as-grid true
gsettings set org.cinnamon.muffin workspace-cycle true

# Configure desktop appearance
gsettings set org.cinnamon.desktop.interface cursor-theme 'Adwaita'
gsettings set org.cinnamon.desktop.interface icon-theme 'Mint-Y'
gsettings set org.cinnamon.desktop.interface font-name 'Ubuntu 11'
gsettings set org.cinnamon.desktop.interface document-font-name 'Sans 11'
gsettings set org.cinnamon.desktop.interface monospace-font-name 'Ubuntu Mono 13'

# Configure window controls
gsettings set org.cinnamon.desktop.wm.preferences button-layout 'menu:minimize,maximize,close'
gsettings set org.cinnamon.desktop.wm.preferences resize-with-right-button true

# Set dark theme
gsettings set org.cinnamon.desktop.interface gtk-theme-backup 'PrivaLinux-Dark'
gsettings set org.cinnamon.theme name 'PrivaLinux-Dark'

# Configure panel and applets for Windows-like experience
gsettings set org.cinnamon panels-enabled "['1:0:bottom']"
gsettings set org.cinnamon panel-zone-icon-sizes '[{"panelId":1,"left":0,"center":0,"right":24}]'
gsettings set org.cinnamon enabled-applets "['panel1:left:0:menu@cinnamon.org', 'panel1:left:1:show-desktop@cinnamon.org', 'panel1:left:2:grouped-window-list@cinnamon.org', 'panel1:right:0:systray@cinnamon.org', 'panel1:right:1:notifications@cinnamon.org', 'panel1:right:2:printers@cinnamon.org', 'panel1:right:3:removable-drives@cinnamon.org', 'panel1:right:4:network@cinnamon.org', 'panel1:right:5:sound@cinnamon.org', 'panel1:right:6:calendar@cinnamon.org', 'panel1:right:7:weather@cinnamon.org']"

# Configure Plank dock for enhanced taskbar experience
mkdir -p /etc/skel/.config/plank/dock1/launchers

# Add applications to Plank dock
cat > /etc/skel/.config/plank/dock1/launchers/firefox.dockitem << EOF
[PlankDockItemPreferences]
Launcher=file:///usr/share/applications/firefox.desktop
EOF

cat > /etc/skel/.config/plank/dock1/launchers/ai-assistant.dockitem << EOF
[PlankDockItemPreferences]
Launcher=file:///etc/skel/Desktop/ai-assistant.desktop
EOF

cat > /etc/skel/.config/plank/dock1/launchers/nemo.dockitem << EOF
[PlankDockItemPreferences]
Launcher=file:///usr/share/applications/nemo.desktop
EOF

cat > /etc/skel/.config/plank/dock1/launchers/gparted.dockitem << EOF
[PlankDockItemPreferences]
Launcher=file:///usr/share/applications/gparted.desktop
EOF

cat > /etc/skel/.config/plank/dock1/launchers/terminal.dockitem << EOF
[PlankDockItemPreferences]
Launcher=file:///usr/share/applications/gnome-terminal.desktop
EOF

cat > /etc/skel/.config/plank/dock1/launchers/synaptic.dockitem << EOF
[PlankDockItemPreferences]
Launcher=file:///usr/share/applications/synaptic.desktop
EOF

# Configure Plank settings
dconf write /net/launchpad/plank/docks/dock1/theme '"Transparent"'
dconf write /net/launchpad/plank/docks/dock1/zoom-enabled true
dconf write /net/launchpad/plank/docks/dock1/zoom-percent 150
dconf write /net/launchpad/plank/docks/dock1/icon-size 48
dconf write /net/launchpad/plank/docks/dock1/position '"bottom"'
dconf write /net/launchpad/plank/docks/dock1/alignment '"center"'
dconf write /net/launchpad/plank/docks/dock1/unhide-delay 0
dconf write /net/launchpad/plank/docks/dock1/hide-delay 0
dconf write /net/launchpad/plank/docks/dock1/hide-mode '"intelligent"'
dconf write /net/launchpad/plank/docks/dock1/lock-items true
dconf write /net/launchpad/plank/docks/dock1/tooltips-enabled true
dconf write /net/launchpad/plank/docks/dock1/pressure-reveal true

# Ensure Plank starts on login
mkdir -p /etc/skel/.config/autostart
cat > /etc/skel/.config/autostart/plank.desktop << EOF
[Desktop Entry]
Type=Application
Name=Plank
Comment=Dock for PrivaLinux OS
Exec=plank
Icon=plank
Terminal=false
Categories=Utility;
StartupNotify=true
X-GNOME-Autostart-enabled=true
EOF

# Configure window management
gsettings set org.cinnamon.muffin edge-tile-threshold 150
gsettings set org.cinnamon.muffin placement-mode 'automatic'
gsettings set org.cinnamon.muffin unredirect-fullscreen-windows true

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