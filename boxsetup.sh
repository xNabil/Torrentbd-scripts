#!/bin/bash

# =========================================================
#  WRAPPER INSTALLER: JERRY048 SEEDBOX + MEDIA TOOLS
# =========================================================

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

LOG_FILE="/root/wrapper_install.log"
> "$LOG_FILE"

# Helper Functions
print_status() { echo -e "${BLUE}[INFO]${NC} $1"; }
print_success() { echo -e "${GREEN}[OK]${NC} $1"; }
print_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# Check Root
if [[ $EUID -ne 0 ]]; then
   print_error "This script must be run as root."
   exit 1
fi

clear
echo -e "${CYAN}"
echo "====================================================="
echo "   SEEDBOX WRAPPER INSTALLER (OFFICIAL SCRIPT)"
echo "====================================================="
echo -e "${NC}"

# =========================================================
#  1. INTERACTIVE CONFIGURATION
# =========================================================

# 1. Username
while true; do
    read -p "Enter Username (for Seedbox & FileBrowser): " username
    if [[ -n "$username" ]]; then break; else echo -e "${RED}Username cannot be empty.${NC}"; fi
done

# 2. Password
while true; do
    read -s -p "Enter Password (min 12 chars): " password
    echo ""
    if [[ ${#password} -ge 12 ]]; then break; else echo -e "${RED}Password too short.${NC}"; fi
done

# 3. Cache
while true; do
    read -p "Enter qBittorrent Cache (in MB, e.g. 1024): " cache
    if [[ "$cache" =~ ^[0-9]+$ ]]; then break; else echo -e "${RED}Must be a number.${NC}"; fi
done

# 4. qBittorrent Version
read -p "Enter qBittorrent Version [Default: 4.6.7]: " qb_ver
qb_ver=${qb_ver:-4.6.7}

# 5. Libtorrent Version
lib_ver="v1.2.19" 

echo ""
echo -e "${YELLOW}:: Component Selection ::${NC}"

# Autobrr
read -p "Install Autobrr? [Y/n]: " auto_p
[[ "$auto_p" =~ ^[Nn]$ ]] && flag_b="" || flag_b="-b"

# Vertex
read -p "Install Vertex? [y/N]: " vert_p
[[ "$vert_p" =~ ^[Yy]$ ]] && flag_v="-v" || flag_v=""

# Autoremove-torrents
read -p "Install Autoremove-torrents? [Y/n]: " remove_p
[[ "$remove_p" =~ ^[Nn]$ ]] && flag_r="" || flag_r="-r"

# BBR Version
read -p "Enable BBRv3 (Recommended)? [Y/n]: " bbr_p
if [[ ! "$bbr_p" =~ ^[Nn]$ ]]; then
    flag_net="-3"
else
    # Ask for BBRx if v3 is declined
    read -p "Enable BBRx instead? [y/N]: " bbrx_p
    [[ "$bbrx_p" =~ ^[Yy]$ ]] && flag_net="-x" || flag_net=""
fi

# =========================================================
#  CONFIRMATION SUMMARY
# =========================================================
echo ""
echo -e "${YELLOW}:: Installation Summary ::${NC}"
echo "-----------------------------------------------------"
echo -e " > Core:      qBittorrent ($qb_ver) + Libtorrent ($lib_ver)"
echo -e " > Tuning:    Cache: ${cache}MB | Network: ${flag_net:1} (if selected)"
echo -e " > Services:  FileBrowser"
echo -e " > Extra Tools: mkbrr, mkvtoolnix, fastfetch, ffmpeg"
echo -e " > Script:    Torrent Creator (/home/$username/Downloads/main.py)"
echo "-----------------------------------------------------"
read -p "Press Enter to start installation..."

echo ""
print_status "Starting Official Installation... This may take time."

# =========================================================
#  2. EXECUTE OFFICIAL SCRIPT
# =========================================================

CMD_FLAGS="-u $username -p $password -c $cache -q $qb_ver -l $lib_ver $flag_b $flag_v $flag_r $flag_net"

echo -e "${YELLOW}Running: Install.sh $CMD_FLAGS${NC}"

# Execute directly
bash <(wget -qO- https://raw.githubusercontent.com/jerry048/Dedicated-Seedbox/main/Install.sh) $CMD_FLAGS

if [ $? -ne 0 ]; then
    print_error "The official script encountered an error."
    read -p "Continue with installing Extra Tools anyway? [y/N]: " cont
    if [[ ! "$cont" =~ ^[Yy]$ ]]; then exit 1; fi
fi

print_success "Official Seedbox Script Finished."
echo ""

# =========================================================
#  3. INSTALL EXTRA MEDIA TOOLS
# =========================================================
print_status "Installing Extra Media Tools..."

# 3.1 Update & Dependencies
apt-get update -y >> "$LOG_FILE" 2>&1
apt-get install -y curl wget gnupg2 sudo lsb-release >> "$LOG_FILE" 2>&1

# 3.2 MKVToolNix
print_status "Installing MKVToolNix..."
{
    wget -q -O /usr/share/keyrings/gpg-pub-moritzbunkus.gpg https://mkvtoolnix.download/gpg-pub-moritzbunkus.gpg
    echo "deb [arch=amd64 signed-by=/usr/share/keyrings/gpg-pub-moritzbunkus.gpg] https://mkvtoolnix.download/debian/ $(lsb_release -sc) main" > /etc/apt/sources.list.d/mkvtoolnix.list
    apt-get update -y
    apt-get install -y mkvtoolnix
} >> "$LOG_FILE" 2>&1
print_success "MKVToolNix installed."

# 3.3 MediaInfo & FFmpeg
print_status "Installing MediaInfo & FFmpeg..."
apt-get install -y mediainfo libmediainfo-dev ffmpeg >> "$LOG_FILE" 2>&1
print_success "FFmpeg & MediaInfo installed."

# 3.4 mkbrr
print_status "Installing mkbrr..."
MKBRR_URL=$(curl -s https://api.github.com/repos/autobrr/mkbrr/releases/latest | grep download | grep linux_amd64.deb | cut -d\" -f4)
if [[ -n "$MKBRR_URL" ]]; then
    wget -q -O mkbrr.deb "$MKBRR_URL" >> "$LOG_FILE" 2>&1
    apt-get install -y ./mkbrr.deb >> "$LOG_FILE" 2>&1
    rm mkbrr.deb
    print_success "mkbrr installed."
else
    print_error "Could not find mkbrr download URL."
fi

# 3.5 Fastfetch
print_status "Installing Fastfetch..."
{
    FF_URL="https://github.com/fastfetch-cli/fastfetch/releases/download/2.55.1/fastfetch-linux-amd64-polyfilled.deb"
    wget -q -O fastfetch.deb "$FF_URL"
    apt-get install -y ./fastfetch.deb
    rm fastfetch.deb
} >> "$LOG_FILE" 2>&1
print_success "Fastfetch installed."

# 3.6 Torrent Creator Script
# TARGET: qBittorrent download path usually /home/$username/Downloads
DL_PATH="/home/$username/Downloads"
# Fallback if Downloads doesn't exist yet
if [ ! -d "$DL_PATH" ]; then
    mkdir -p "$DL_PATH"
    chown "$username":"$username" "$DL_PATH"
fi

print_status "Downloading Torrent Creator to $DL_PATH..."
wget -q -O "$DL_PATH/main.py" https://raw.githubusercontent.com/xNabil/torrent-creator/refs/heads/main/main.py
chown "$username":"$username" "$DL_PATH/main.py"
chmod +x "$DL_PATH/main.py"
print_success "Script saved to $DL_PATH/main.py"

# =========================================================
#  4. INSTALL FILEBROWSER
# =========================================================
print_status "Installing & Configuring FileBrowser..."

# Install
curl -fsSL https://raw.githubusercontent.com/filebrowser/get/master/get.sh | bash >> "$LOG_FILE" 2>&1

# Service File
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

# Initialize DB
systemctl daemon-reload
# Temporarily start to create DB file if missing
if [ ! -f /root/filebrowser.db ]; then
   timeout 5s /usr/local/bin/filebrowser --database /root/filebrowser.db --root / --port 808 >/dev/null 2>&1
fi

# Add User (Using same credentials as Seedbox)
/usr/local/bin/filebrowser users add "$username" "$password" --perm.admin --database /root/filebrowser.db >> "$LOG_FILE" 2>&1 || \
/usr/local/bin/filebrowser users update "$username" --password "$password" --perm.admin --database /root/filebrowser.db >> "$LOG_FILE" 2>&1

# Enable & Start
systemctl enable filebrowser >> "$LOG_FILE" 2>&1
systemctl restart filebrowser
print_success "FileBrowser running on Port 808."

# =========================================================
#  FINAL SUMMARY
# =========================================================
PUBLIC_IP=$(curl -s https://api.ipify.org || hostname -I | awk '{print $1}')

echo ""
echo -e "${GREEN}=====================================================${NC}"
echo -e "${GREEN}             INSTALLATION COMPLETE                   ${NC}"
echo -e "${GREEN}=====================================================${NC}"
echo ""
echo -e "   ${YELLOW}User${NC}          : $username"
echo -e "   ${YELLOW}Password${NC}      : $password"
echo ""
echo -e "   ${YELLOW}FileBrowser${NC}   : http://$PUBLIC_IP:808"
echo -e "   ${YELLOW}qBittorrent${NC}   : http://$PUBLIC_IP:8080"
if [[ -n "$flag_b" ]]; then
echo -e "   ${YELLOW}Autobrr${NC}       : http://$PUBLIC_IP:7474"
fi
if [[ -n "$flag_v" ]]; then
echo -e "   ${YELLOW}Vertex${NC}        : http://$PUBLIC_IP:3000"
fi
echo ""
echo -e "   ${YELLOW}Extra Tools${NC}   : FFmpeg, MediaInfo, MKVToolNix, mkbrr, Fastfetch"
echo -e "   ${YELLOW}Torrent Creation Script Path${NC}   : $DL_PATH/main.py"
echo ""
echo -e "   ${CYAN}Note: If BBRv3 was installed, please reboot your server.${NC}"
echo -e "${GREEN}=====================================================${NC}"
exit 0
