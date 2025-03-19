#!/bin/bash

# PrivaLinux OS Privacy Configuration Script
# This script configures privacy settings and installs privacy-focused applications

set -e

echo "[+] Configuring privacy settings for PrivaLinux OS"

# Load configuration
source /tmp/privacy_settings.conf

# Configure GNOME privacy settings
echo "[+] Configuring GNOME privacy settings"
gsettings set org.gnome.desktop.privacy remember-recent-files false
gsettings set org.gnome.desktop.privacy remove-old-temp-files true
gsettings set org.gnome.desktop.privacy remove-old-trash-files true
gsettings set org.gnome.desktop.privacy hide-identity true
gsettings set org.gnome.desktop.privacy report-technical-problems false
gsettings set org.gnome.desktop.privacy send-software-usage-stats false
gsettings set org.gnome.system.location enabled false
gsettings set org.gnome.desktop.search-providers disable-external true

# Configure Brave as default browser
echo "[+] Configuring Brave browser for enhanced privacy"
xdg-settings set default-web-browser brave-browser.desktop

# Configure Brave browser privacy settings
mkdir -p /etc/brave/policies/managed/
cat > /etc/brave/policies/managed/privacy.json << EOF
{
    "DefaultSearchProviderEnabled": true,
    "DefaultSearchProviderName": "DuckDuckGo",
    "DefaultSearchProviderSearchURL": "https://duckduckgo.com/?q={searchTerms}",
    "DNSOverHttpsMode": "secure",
    "PasswordManagerEnabled": false,
    "SafeBrowsingEnabled": true,
    "SearchSuggestEnabled": false,
    "SpellCheckServiceEnabled": false,
    "SyncDisabled": true,
    "MetricsReportingEnabled": false
}
EOF

# Configure Zen browser as alternative
echo "[+] Setting up Zen browser as alternative browser"
mkdir -p /etc/skel/.mozilla/zen/privalinux.default
cat > /etc/skel/.mozilla/zen/privalinux.default/user.js << EOF
// Disable telemetry
user_pref("toolkit.telemetry.enabled", false);
user_pref("toolkit.telemetry.unified", false);
user_pref("toolkit.telemetry.archive.enabled", false);
user_pref("browser.ping-centre.telemetry", false);
user_pref("browser.newtabpage.activity-stream.feeds.telemetry", false);
user_pref("browser.newtabpage.activity-stream.telemetry", false);

// Enhanced tracking protection
user_pref("privacy.trackingprotection.enabled", true);
user_pref("privacy.trackingprotection.pbmode.enabled", true);
user_pref("privacy.trackingprotection.fingerprinting.enabled", true);
user_pref("privacy.trackingprotection.cryptomining.enabled", true);
user_pref("privacy.trackingprotection.socialtracking.enabled", true);

// Disable prefetching
user_pref("network.prefetch-next", false);
user_pref("network.dns.disablePrefetch", true);
user_pref("network.predictor.enabled", false);
user_pref("network.predictor.enable-prefetch", false);

// Set default search engine to DuckDuckGo
user_pref("browser.urlbar.placeholderName", "DuckDuckGo");
user_pref("browser.urlbar.placeholderName.private", "DuckDuckGo");

// Enable HTTPS-Only Mode
user_pref("dom.security.https_only_mode", true);
user_pref("dom.security.https_only_mode_ever_enabled", true);

// Disable geolocation
user_pref("geo.enabled", false);

// Disable WebRTC
user_pref("media.peerconnection.enabled", false);

// Disable data reporting
user_pref("datareporting.healthreport.uploadEnabled", false);
user_pref("datareporting.policy.dataSubmissionEnabled", false);
user_pref("datareporting.sessions.current.clean", true);

// Disable Pocket
user_pref("extensions.pocket.enabled", false);

// Disable form autofill
user_pref("browser.formfill.enable", false);
user_pref("extensions.formautofill.addresses.enabled", false);
user_pref("extensions.formautofill.creditCards.enabled", false);

// Disable studies
user_pref("app.shield.optoutstudies.enabled", false);

// Disable crash reports
user_pref("breakpad.reportURL", "");
user_pref("browser.tabs.crashReporting.sendReport", false);

// Disable recommendations
user_pref("browser.newtabpage.activity-stream.asrouter.userprefs.cfr.addons", false);
user_pref("browser.newtabpage.activity-stream.asrouter.userprefs.cfr.features", false);

// Enable Do Not Track
user_pref("privacy.donottrackheader.enabled", true);

// Block third-party cookies
user_pref("network.cookie.cookieBehavior", 1);
EOF

# Configure system-wide DNS over HTTPS
if [ "$DNS_OVER_HTTPS" = "true" ]; then
    echo "[+] Configuring DNS over HTTPS"
    mkdir -p /etc/systemd/resolved.conf.d/
    cat > /etc/systemd/resolved.conf.d/dns-over-https.conf << EOF
[Resolve]
DNS=$DEFAULT_DNS_PROVIDER
DNSOverTLS=yes
EOF
fi

# Configure firewall
if [ "$ENABLE_FIREWALL" = "true" ]; then
    echo "[+] Configuring firewall"
    ufw default deny incoming
    ufw default allow outgoing
    ufw enable
fi

# Configure AppArmor for application sandboxing
if [ "$ENABLE_APP_SANDBOXING" = "true" ]; then
    echo "[+] Configuring AppArmor for application sandboxing"
    systemctl enable apparmor
    systemctl start apparmor
fi

# Install and configure Firejail for application sandboxing
if [ "$ENABLE_APP_SANDBOXING" = "true" ]; then
    echo "[+] Configuring Firejail profiles"
    
    # Create Firejail desktop integration
    mkdir -p /etc/firejail
    cat > /etc/firejail/firecfg.config << EOF
# PrivaLinux OS Firejail Configuration

# Web browsers
zen-browser
brave-browser

# Email clients
thunderbird

# Office applications
libreoffice

# Media players
vlc

# File managers
thunar

# PDF viewers
evince

# Wine applications
wine
winecfg
winetricks
EOF
    
    # Run Firejail setup
    firecfg --fix
fi

# Configure automatic updates
if [ "$ENABLE_AUTOMATIC_UPDATES" = "true" ]; then
    echo "[+] Configuring automatic security updates"
    apt-get install -y unattended-upgrades apt-listchanges
    cat > /etc/apt/apt.conf.d/20auto-upgrades << EOF
APT::Periodic::Update-Package-Lists "1";
APT::Periodic::Unattended-Upgrade "1";
APT::Periodic::AutocleanInterval "7";
EOF
    
    cat > /etc/apt/apt.conf.d/50unattended-upgrades << EOF
Unattended-Upgrade::Allowed-Origins {
    "${distro_id}:${distro_codename}";
    "${distro_id}:${distro_codename}-security";
    "${distro_id}ESMApps:${distro_codename}-apps-security";
    "${distro_id}ESM:${distro_codename}-infra-security";
};
Unattended-Upgrade::Package-Blacklist {
};
Unattended-Upgrade::AutoFixInterruptedDpkg "true";
Unattended-Upgrade::MinimalSteps "true";
Unattended-Upgrade::InstallOnShutdown "false";
Unattended-Upgrade::Remove-Unused-Dependencies "true";
Unattended-Upgrade::Automatic-Reboot "false";
EOF
fi

# Create privacy documentation
echo "[+] Creating privacy documentation"
mkdir -p /usr/share/doc/privalinux/privacy
cat > /usr/share/doc/privalinux/privacy/README.md << EOF
# PrivaLinux OS Privacy Guide

PrivaLinux OS is designed with privacy as a core principle. This guide explains the privacy features and how to make the most of them.

## Privacy Features

### System-Level Privacy

- **Minimal Telemetry**: All system-level telemetry and data collection is disabled by default
- **Automatic Updates**: Security updates are automatically installed to protect your system
- **Firewall**: A preconfigured firewall blocks unwanted incoming connections
- **Disk Encryption**: Full disk encryption is available during installation
- **DNS over HTTPS**: All DNS queries are encrypted to prevent snooping

### Application Privacy

- **Sandboxed Applications**: Applications run in isolated environments using Firejail
- **Permission Control**: Fine-grained control over application permissions
- **Privacy-Focused Defaults**: All applications are configured with privacy-enhancing defaults

### Browser Privacy

- **Privacy-Focused Browsers**: Brave (Chromium-based) and Zen Browser (Gecko-based) with enhanced privacy settings
- **Enhanced Tracking Protection**: Blocks trackers and fingerprinting attempts
- **HTTPS-Only Mode**: Ensures encrypted connections to websites
- **Privacy-Focused Search**: Uses DuckDuckGo as the default search engine
- **No Telemetry**: Browser telemetry and crash reporting are disabled

## Privacy Tools Included

- **KeePassXC**: Secure password management
- **VeraCrypt**: Strong disk encryption
- **BleachBit**: System cleaning and privacy tool
- **Tor Browser**: Anonymous web browsing
- **Signal/Element**: Secure messaging applications

## Privacy Best Practices

1. **Keep Your System Updated**: Regular updates patch security vulnerabilities
2. **Use Strong, Unique Passwords**: Utilize KeePassXC to manage them
3. **Be Cautious with Extensions**: Only install necessary browser extensions from trusted sources
4. **Use a VPN**: Consider using a reputable VPN service for additional privacy
5. **Regular Privacy Audits**: Use the included privacy tools to audit your system regularly

## Additional Privacy Resources

- Electronic Frontier Foundation: https://www.eff.org
- Privacy Tools: https://www.privacytools.io
- Surveillance Self-Defense: https://ssd.eff.org

For more information on PrivaLinux OS privacy features, visit our website or community forums.
EOF

echo "[+] Privacy configuration completed successfully"