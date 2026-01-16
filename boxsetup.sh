#!/bin/bash

# =========================================================
#  Automated Media Server Installer
#  Inspired by Jerry048/Dedicated-Seedbox
# =========================================================

# Colors for formatting
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Check if running as root
if [[ $EUID -ne 0 ]]; then
   echo -e "${RED}This script must be run as root.${NC}" 
   exit 1
fi

# =========================================================
#  INPUTS
# =========================================================
clear
echo -e "${BLUE}"
echo "====================================================="
echo "      MEDIA TOOLS INSTALLATION SCRIPT"
echo "====================================================="
echo -e "${NC}"

# Prompt for FileBrowser credentials
echo -e "${YELLOW}Please enter credentials for FileBrowser:${NC}"
read -p "Username: " FB_USER
read -s -p "Password: " FB_PASS
echo ""

if [[ -z "$FB_USER" || -z "$FB_PASS" ]]; then
    echo -e "${RED}Error: Username and Password cannot be empty.${NC}"
    exit 1
fi

echo -e "\n${GREEN}Starting Installation...${NC}\n"

# =========================================================
#  1. UPDATE SYSTEM
# =========================================================
echo -e "${BLUE}[1/8] Updating System Repositories...${NC}"
apt update -y
apt install -y curl wget gnupg2 sudo

# =========================================================
#  2. MKVTOOLNIX (Specific Version)
# =========================================================
echo -e "${BLUE}[2/8] Installing MKVToolNix...${NC}"
MKV_URL="https://mkvtoolnix.download/debian/pool/bookworm/main/m/mkvtoolnix/mkvtoolnix_96.0-0~debian12bunkus01_amd64.deb"
MKV_DEB="mkvtoolnix.deb"

wget -q --show-progress -O "$MKV_DEB" "$MKV_URL"
apt install -y "./$MKV_DEB"
rm "$MKV_DEB"

# =========================================================
#  3. MEDIAINFO & FFMPEG
# =========================================================
echo -e "${BLUE}[3/8] Installing MediaInfo and FFmpeg...${NC}"
apt install -y mediainfo libmediainfo-dev ffmpeg

# =========================================================
#  4. MKBRR (Dynamic Fetch)
# =========================================================
echo -e "${BLUE}[4/8] Installing mkbrr (Latest)...${NC}"
MKBRR_URL=$(curl -s https://api.github.com/repos/autobrr/mkbrr/releases/latest | grep download | grep linux_amd64.deb | cut -d\" -f4)
MKBRR_DEB="mkbrr_latest.deb"

if [[ -n "$MKBRR_URL" ]]; then
    wget -q --show-progress -O "$MKBRR_DEB" "$MKBRR_URL"
    apt install -y "./$MKBRR_DEB"
    rm "$MKBRR_DEB"
else
    echo -e "${RED}Failed to fetch mkbrr download URL.${NC}"
fi

# =========================================================
#  5. FASTFETCH
# =========================================================
echo -e "${BLUE}[5/8] Installing Fastfetch...${NC}"
# Adding the repo key/list as requested
echo "deb [signed-by=/etc/apt/keyrings/fastfetch.gpg] http://repo.fastfetch.dev/debian/ generic main" | tee /etc/apt/sources.list.d/fastfetch.list > /dev/null
mkdir -p /etc/apt/keyrings

# Installing the specific requested DEB
FF_URL="https://github.com/fastfetch-cli/fastfetch/releases/download/2.55.1/fastfetch-linux-amd64-polyfilled.deb"
FF_DEB="fastfetch.deb"

wget -q --show-progress -O "$FF_DEB" "$FF_URL"
apt install -y "./$FF_DEB"
rm "$FF_DEB"

# =========================================================
#  6. FILEBROWSER INSTALLATION
# =========================================================
echo -e "${BLUE}[6/8] Installing FileBrowser...${NC}"
curl -fsSL https://raw.githubusercontent.com/filebrowser/get/master/get.sh | bash

# Create Systemd Service
echo -e "${YELLOW}Creating systemd service file...${NC}"
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

# =========================================================
#  7. CONFIGURE FILEBROWSER USER
# =========================================================
echo -e "${BLUE}[7/8] Configuring FileBrowser User...${NC}"
# Reload and start temporarily to ensure DB is created, then stop
systemctl daemon-reload
systemctl enable filebrowser
systemctl start filebrowser
sleep 2
systemctl stop filebrowser

# Add User (Using the variables captured at start)
/usr/local/bin/filebrowser users add "$FB_USER" "$FB_PASS" --perm.admin --database /root/filebrowser.db

# Restart service
systemctl start filebrowser

# =========================================================
#  8. TORRENT CREATOR SCRIPT
# =========================================================
echo -e "${BLUE}[8/8] Downloading Torrent Creator Script...${NC}"
wget -q -O main.py https://raw.githubusercontent.com/xNabil/torrent-creator/refs/heads/main/main.py

# =========================================================
#  COMPLETION
# =========================================================
echo -e "\n${GREEN}=========================================${NC}"
echo -e "${GREEN}   INSTALLATION COMPLETE SUCCESSFULLY    ${NC}"
echo -e "${GREEN}=========================================${NC}"
echo -e "FileBrowser is running on port 808."
echo -e "Username: $FB_USER"
echo -e "Password: (hidden)"
echo -e "Torrent Creator script saved as: main.py"
echo -e "\n"
