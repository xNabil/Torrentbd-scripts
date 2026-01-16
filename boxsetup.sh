#!/bin/bash

# =========================================================
#  MINIMALIST MEDIA SERVER INSTALLER
#  Logs are saved to: /root/media-install.log
# =========================================================

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

LOG_FILE="/root/media-install.log"

# Clear log file
> "$LOG_FILE"

# Helper functions
function print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

function print_success() {
    echo -e "${GREEN}[OK]${NC} $1"
}

function print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Root Check
if [[ $EUID -ne 0 ]]; then
   print_error "This script must be run as root."
   exit 1
fi

clear
echo -e "${CYAN}"
echo "====================================================="
echo "      MEDIA TOOLS INSTALLATION SCRIPT"
echo "====================================================="
echo -e "${NC}"

# =========================================================
#  1. CONFIGURATION & VALIDATION
# =========================================================
echo -e "${YELLOW}:: Configuration ::${NC}"

# Username Input
while true; do
    read -p "Enter FileBrowser Username: " FB_USER
    if [[ -n "$FB_USER" ]]; then
        break
    else
        echo -e "${RED}Username cannot be empty.${NC}"
    fi
done

# Password Input (Min 12 Chars)
while true; do
    read -s -p "Enter FileBrowser Password (min 12 chars): " FB_PASS
    echo ""
    
    if [[ ${#FB_PASS} -ge 12 ]]; then
        break
    else
        echo -e "${RED}Error: Password is too short. It must be at least 12 characters.${NC}"
    fi
done

echo ""
print_status "Installation started. Logs: $LOG_FILE"
echo "-----------------------------------------------------"

# =========================================================
#  2. INSTALLATION STEPS
# =========================================================

# System Update
print_status "Updating system repositories..."
{
    apt-get update -y
    apt-get install -y curl wget gnupg2 sudo lsb-release
} >> "$LOG_FILE" 2>&1
print_success "System updated."

# MKVToolNix
print_status "Installing MKVToolNix (v96.0)..."
MKV_URL="https://mkvtoolnix.download/debian/pool/bookworm/main/m/mkvtoolnix/mkvtoolnix_96.0-0~debian12bunkus01_amd64.deb"
{
    wget -q -O mkvtoolnix.deb "$MKV_URL"
    apt-get install -y ./mkvtoolnix.deb
    rm mkvtoolnix.deb
} >> "$LOG_FILE" 2>&1
print_success "MKVToolNix installed."

# MediaInfo & FFmpeg
print_status "Installing MediaInfo & FFmpeg..."
{
    apt-get install -y mediainfo libmediainfo-dev ffmpeg
} >> "$LOG_FILE" 2>&1
print_success "Media libraries installed."

# mkbrr
print_status "Fetching and installing mkbrr..."
{
    MKBRR_URL=$(curl -s https://api.github.com/repos/autobrr/mkbrr/releases/latest | grep download | grep linux_amd64.deb | cut -d\" -f4)
    if [[ -n "$MKBRR_URL" ]]; then
        wget -q -O mkbrr.deb "$MKBRR_URL"
        apt-get install -y ./mkbrr.deb
        rm mkbrr.deb
    else
        echo "Failed to find mkbrr URL" >> "$LOG_FILE"
    fi
} >> "$LOG_FILE" 2>&1
print_success "mkbrr installed."

# Fastfetch
print_status "Installing Fastfetch..."
{
    echo "deb [signed-by=/etc/apt/keyrings/fastfetch.gpg] http://repo.fastfetch.dev/debian/ generic main" | tee /etc/apt/sources.list.d/fastfetch.list
    mkdir -p /etc/apt/keyrings
    
    FF_URL="https://github.com/fastfetch-cli/fastfetch/releases/download/2.55.1/fastfetch-linux-amd64-polyfilled.deb"
    wget -q -O fastfetch.deb "$FF_URL"
    apt-get install -y ./fastfetch.deb
    rm fastfetch.deb
} >> "$LOG_FILE" 2>&1
print_success "Fastfetch installed."

# FileBrowser
print_status "Installing FileBrowser..."
{
    curl -fsSL https://raw.githubusercontent.com/filebrowser/get/master/get.sh | bash
} >> "$LOG_FILE" 2>&1

print_status "Configuring FileBrowser Service..."
cat <<EOF > /etc/systemd/system/filebrowser.service
[Unit]
Description=File Browser
After=network.target

[Service]
User=root
Group=root
ExecStart=/usr/local/bin/filebrowser \\
  --database /root/filebrowser.db \\
  --root / \\
  --address 0.0.0.0 \\
  --port 808
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

{
    systemctl daemon-reload
    systemctl enable filebrowser
    systemctl start filebrowser
    sleep 3
    systemctl stop filebrowser
    
    # Add User
    /usr/local/bin/filebrowser users add "$FB_USER" "$FB_PASS" --perm.admin --database /root/filebrowser.db
    
    systemctl start filebrowser
} >> "$LOG_FILE" 2>&1
print_success "FileBrowser configured and running."

# Torrent Creator
print_status "Downloading Torrent Creator script..."
wget -q -O /root/main.py https://raw.githubusercontent.com/xNabil/torrent-creator/refs/heads/main/main.py
print_success "Script saved to /root/main.py"

# =========================================================
#  FINAL SUMMARY
# =========================================================

# Detect IP
PUBLIC_IP=$(curl -s https://api.ipify.org || hostname -I | awk '{print $1}')

echo ""
echo -e "${GREEN}=====================================================${NC}"
echo -e "${GREEN}             INSTALLATION COMPLETE                   ${NC}"
echo -e "${GREEN}=====================================================${NC}"
echo ""
echo -e "   ${YELLOW}Service${NC}        : FileBrowser"
echo -e "   ${YELLOW}Status${NC}         : ${GREEN}Active (Running)${NC}"
echo -e "   ${YELLOW}URL${NC}            : http://$PUBLIC_IP:808"
echo -e "   ${YELLOW}Username${NC}       : $FB_USER"
echo -e "   ${YELLOW}Password${NC}       : $FB_PASS"
echo -e "   ${YELLOW}Database${NC}       : /root/filebrowser.db"
echo ""
echo -e "   ${YELLOW}Extra Tools${NC}    : mkbrr, mkvtoolnix, fastfetch, ffmpeg"
echo -e "   ${YELLOW}Torrent Script${NC} : /root/main.py"
echo ""
echo -e "${GREEN}=====================================================${NC}"
echo -e "Logs saved to: $LOG_FILE"
echo ""
