#!/bin/bash

# PrivaLinux OS Wine Configuration Script
# This script configures Wine for optimal Windows application compatibility

set -e

echo "[+] Configuring Wine for PrivaLinux OS"

# Install Wine and dependencies
apt-get update
apt-get install -y \
    wine \
    wine-gecko \
    wine-mono \
    winetricks \
    cabextract \
    p7zip-full \
    winbind

# Create Wine prefix directory structure
WINE_PREFIX="/etc/skel/.wine"

# Set up Wine prefix with recommended settings
WINEPREFIX="$WINE_PREFIX" WINEARCH="win64" wine wineboot --init

# Install common Windows components using winetricks
WINEPREFIX="$WINE_PREFIX" winetricks -q corefonts
WINEPREFIX="$WINE_PREFIX" winetricks -q d3dx9
WINEPREFIX="$WINE_PREFIX" winetricks -q vcrun2010
WINEPREFIX="$WINE_PREFIX" winetricks -q vcrun2013
WINEPREFIX="$WINE_PREFIX" winetricks -q vcrun2015
WINEPREFIX="$WINE_PREFIX" winetricks -q dotnet48

# Configure Wine for better compatibility
WINEPREFIX="$WINE_PREFIX" wine regedit /S /etc/privalinux/wine/better_compatibility.reg

# Create desktop shortcuts for Wine configuration tools
cat > /etc/skel/Desktop/wine-config.desktop << EOF
[Desktop Entry]
Name=Wine Configuration
Exec=wine winecfg
Type=Application
Icon=wine-winecfg
Categories=Wine;
EOF

cat > /etc/skel/Desktop/winetricks.desktop << EOF
[Desktop Entry]
Name=Winetricks
Exec=winetricks
Type=Application
Icon=wine-winetricks
Categories=Wine;
EOF

# Create Wine registry tweaks for better performance and compatibility
mkdir -p /etc/privalinux/wine

cat > /etc/privalinux/wine/better_compatibility.reg << EOF
WINDOWS REGISTRY EDITOR VERSION 5.00

[HKEY_CURRENT_USER\Software\Wine\Direct3D]
"MaxVersionGL"=dword:00000004
"DirectDrawRenderer"="opengl"
"RenderTargetLockMode"="auto"
"StrictDrawOrdering"="enabled"
"UseGLSL"="enabled"
"VideoMemorySize"="1024"

[HKEY_CURRENT_USER\Software\Wine\X11 Driver]
"GrabFullscreen"="Y"
"Decorated"="Y"
"DXGrab"="Y"

[HKEY_CURRENT_USER\Software\Wine\DirectInput]
"MouseWarpOverride"="enable"

[HKEY_CURRENT_USER\Control Panel\Desktop]
"FontSmoothing"="2"
"FontSmoothingType"=dword:00000002
"FontSmoothingGamma"=dword:00000578
"FontSmoothingOrientation"=dword:00000001
EOF

# Create documentation for Wine usage
mkdir -p /usr/share/doc/privalinux/wine

cat > /usr/share/doc/privalinux/wine/README.md << EOF
# Wine in PrivaLinux OS

PrivaLinux OS comes with Wine pre-installed and pre-configured for optimal Windows application compatibility.

## Using Wine

1. **Running Windows Applications**
   - Right-click on a Windows .exe file and select "Open with Wine Windows Program Loader"
   - Or open a terminal and run: \`wine /path/to/program.exe\`

2. **Wine Configuration**
   - Use the Wine Configuration desktop shortcut
   - Or run \`winecfg\` in a terminal

3. **Installing Windows Software**
   - Run the installer with Wine: \`wine installer.exe\`
   - Use Winetricks for common software: \`winetricks\`

4. **Troubleshooting**
   - Check the Wine AppDB for compatibility: https://appdb.winehq.org
   - Run programs with debug info: \`WINEDEBUG=+all wine program.exe\`
   - Visit the Wine forum for help: https://forum.winehq.org

## Pre-installed Components

- Wine 7.0 (or latest stable)
- Wine Gecko (for IE functionality)
- Wine Mono (.NET implementation)
- Winetricks (helper script)
- Common Windows libraries and fonts

## Privacy Considerations

Wine creates a virtual Windows environment that is isolated from your Linux system. However, Windows applications running in Wine can still:

- Connect to the internet
- Access files in your home directory
- Potentially contain malware

For maximum privacy and security:

1. Run Wine applications in Firejail: \`firejail wine program.exe\`
2. Use a separate Wine prefix for untrusted applications
3. Configure your firewall to control Wine application network access

For more information, see the full Wine documentation at https://wiki.winehq.org
EOF

echo "[+] Wine configuration completed successfully"