#!/bin/bash
tput sgr0; clear

# =========================================================
#  SEEDBOX + MEDIA CENTER INSTALLER (INTERACTIVE)
# =========================================================

# Colors for modern output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'
LOG_FILE="/root/media-install.log"

## Load Seedbox Components (Original Logic)
# We load this early to get helper functions, but we will handle errors manually
source <(wget -qO- https://raw.githubusercontent.com/jerry048/Seedbox-Components/main/seedbox_installation.sh)

# Check if Seedbox Components loaded
if [ $? -ne 0 ]; then
    echo -e "${RED}Component ~Seedbox Components~ failed to load${NC}"
    echo "Check connection with GitHub"
    exit 1
fi

## Load loading animation
source <(wget -qO- https://raw.githubusercontent.com/Silejonu/bash_loading_animations/main/bash_loading_animations.sh)
if [ $? -ne 0 ]; then
    echo -e "${RED}Component ~Bash loading animation~ failed to load${NC}"
    exit 1
fi

# Fix: Ensure function exists before trapping
if declare -f BLA::stop_loading_animation > /dev/null; then
    trap BLA::stop_loading_animation SIGINT
fi

## Install function wrapper (Preserved from original)
install_() {
    info_2 "$2"
    BLA::start_loading_animation "${BLA_classic[@]}"
    $1 1> /dev/null 2> $3
    if [ $? -ne 0 ]; then
        fail_3 "FAIL" 
    else
        info_3 "Successful"
        export $4=1
    fi
    BLA::stop_loading_animation
}

## Installation environment Check
info "Checking Installation Environment"

# Check Root Privilege
if [ "$(id -u)" -ne 0 ]; then
    fail_exit "This script needs root permission to run"
fi

# Linux Distro Version check
if [ -f /etc/os-release ]; then
    . /etc/os-release
    OS=$NAME
    VER=$VERSION_ID
else
    OS=$(uname -s)
    VER=$(uname -r)
fi

# =========================================================
#  1. INTERACTIVE CONFIGURATION
# =========================================================
clear
echo -e "${CYAN}"
echo "====================================================="
echo "      SEEDBOX & MEDIA TOOLS INSTALLATION"
echo "====================================================="
echo -e "${NC}"
echo -e "${YELLOW}:: Configuration ::${NC}"

# 1. Username
while true; do
    read -p "Enter Username (for all services): " username
    if [[ -n "$username" ]]; then
        break
    else
        echo -e "${RED}Username cannot be empty.${NC}"
    fi
done

# 2. Password (Min 12 Chars)
while true; do
    read -s -p "Enter Password (min 12 chars): " password
    echo ""
    if [[ ${#password} -ge 12 ]]; then
        break
    else
        echo -e "${RED}Error: Password is too short. It must be at least 12 characters.${NC}"
    fi
done

# 3. Cache Size
while true; do
    read -p "Enter Cache Size in MB (e.g., 1024): " cache
    if [[ "$cache" =~ ^[0-9]+$ ]]; then
        qb_cache=$cache
        break
    else
        echo -e "${RED}Cache must be a number.${NC}"
    fi
done

echo ""
echo -e "${YELLOW}:: Software Selection ::${NC}"

# Defaults
qb_install=1
# Defaulting to stable versions to avoid complex flag parsing
qb_ver="qBittorrent-4.6.3" 
lib_ver="libtorrent-v1.2.19"
qb_port=8080
qb_incoming_port=45000

# Prompt for components
read -p "Install Autobrr? [Y/n]: " prompt_autobrr
[[ "$prompt_autobrr" =~ ^[Nn]$ ]] && autobrr_install="" || autobrr_install=1

read -p "Install Vertex? [y/N]: " prompt_vertex
[[ "$prompt_vertex" =~ ^[Yy]$ ]] && vertex_install=1 || vertex_install=""

read -p "Install BBRv3 (TCP Tuning)? [Y/n]: " prompt_bbr
if [[ ! "$prompt_bbr" =~ ^[Nn]$ ]]; then
    bbrv3_install=1
    unset bbrx_install
else
    bbrv3_install=""
fi

# FileBrowser is mandatory per request
filebrowser_install=1

echo ""
print_status "Installation started. Logs: $LOG_FILE"
echo "-----------------------------------------------------"

# System Update & Dependencies Install
info "Start System Update & Dependencies Install"
update

## Install Seedbox Environment
tput sgr0; clear
info "Start Installing Seedbox Environment"
echo -e "\n"

# =========================================================
#  2. SEEDBOX COMPONENT INSTALLATION
# =========================================================

# Load qBittorrent Installer Script
source <(wget -qO- https://raw.githubusercontent.com/jerry048/Seedbox-Components/main/Torrent%20Clients/qBittorrent/qBittorrent_install.sh)

# qBittorrent Install
if [[ -n "$qb_install" ]]; then
    # Create user if not exists
    if ! id -u $username > /dev/null 2>&1; then
        useradd -m -s /bin/bash $username
    fi
    chown -R $username:$username /home/$username
    
    # Run Install Wrapper
    install_ "install_qBittorrent_ $username $password $qb_ver $lib_ver $qb_cache $qb_port $qb_incoming_port" "Installing qBittorrent ($qb_ver)" "/tmp/qb_error" qb_install_success
fi

# autobrr Install
if [[ -n "$autobrr_install" ]]; then
    # Default port if not set
    autobrr_port=7474
    install_ install_autobrr_ "Installing autobrr" "/tmp/autobrr_error" autobrr_install_success
fi

# vertex Install
if [[ -n "$vertex_install" ]]; then
    vertex_port=3000
    install_ install_vertex_ "Installing vertex" "/tmp/vertex_error" vertex_install_success
fi

# =========================================================
#  3. NEW MEDIA TOOLS INSTALLATION
# =========================================================
seperator
info "Installing Extra Media Tools"

# Define a wrapper for standard shell commands to fit the 'install_' style
run_shell_cmd() {
    bash -c "$1"
}

# 3.1 MKVToolNix
install_mkvtoolnix() {
    MKV_URL="https://mkvtoolnix.download/debian/pool/bookworm/main/m/mkvtoolnix/mkvtoolnix_96.0-0~debian12bunkus01_amd64.deb"
    wget -q -O mkvtoolnix.deb "$MKV_URL" && \
    apt-get install -y ./mkvtoolnix.deb && \
    rm mkvtoolnix.deb
}
install_ install_mkvtoolnix "Installing MKVToolNix (v96.0)" "/tmp/mkv_error" mkv_success

# 3.2 MediaInfo & FFmpeg
install_ffmpeg() {
    apt-get install -y mediainfo libmediainfo-dev ffmpeg
}
install_ install_ffmpeg "Installing MediaInfo & FFmpeg" "/tmp/ffmpeg_error" ffmpeg_success

# 3.3 mkbrr
install_mkbrr() {
    MKBRR_URL=$(curl -s https://api.github.com/repos/autobrr/mkbrr/releases/latest | grep download | grep linux_amd64.deb | cut -d\" -f4)
    if [[ -n "$MKBRR_URL" ]]; then
        wget -q -O mkbrr.deb "$MKBRR_URL"
        apt-get install -y ./mkbrr.deb
        rm mkbrr.deb
    else
        return 1
    fi
}
install_ install_mkbrr "Installing mkbrr" "/tmp/mkbrr_error" mkbrr_success

# 3.4 Fastfetch
install_fastfetch() {
    echo "deb [signed-by=/etc/apt/keyrings/fastfetch.gpg] http://repo.fastfetch.dev/debian/ generic main" | tee /etc/apt/sources.list.d/fastfetch.list
    mkdir -p /etc/apt/keyrings
    FF_URL="https://github.com/fastfetch-cli/fastfetch/releases/download/2.55.1/fastfetch-linux-amd64-polyfilled.deb"
    wget -q -O fastfetch.deb "$FF_URL"
    apt-get install -y ./fastfetch.deb
    rm fastfetch.deb
}
install_ install_fastfetch "Installing Fastfetch" "/tmp/fastfetch_error" fastfetch_success

# 3.5 Torrent Creator Script
install_torrent_creator() {
    wget -q -O /root/main.py https://raw.githubusercontent.com/xNabil/torrent-creator/refs/heads/main/main.py
}
install_ install_torrent_creator "Downloading Torrent Creator" "/tmp/creator_error" creator_success

# 3.6 FileBrowser
install_filebrowser() {
    # Install binary
    curl -fsSL https://raw.githubusercontent.com/filebrowser/get/master/get.sh | bash
    
    # Create Service
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

    # Init DB and User
    systemctl daemon-reload
    # Create DB file by starting momentarily or manually
    if [ ! -f /root/filebrowser.db ]; then
       # Temporary run to generate DB
       timeout 5s /usr/local/bin/filebrowser --database /root/filebrowser.db --root / --port 808 >/dev/null 2>&1
    fi
    
    # Add User (using the global username/password)
    /usr/local/bin/filebrowser users add "$username" "$password" --perm.admin --database /root/filebrowser.db 2>/dev/null || \
    /usr/local/bin/filebrowser users update "$username" --password "$password" --perm.admin --database /root/filebrowser.db
    
    # Enable and Start
    systemctl enable filebrowser
    systemctl restart filebrowser
}
install_ install_filebrowser "Installing FileBrowser" "/tmp/fb_error" fb_success

# =========================================================
#  4. SYSTEM TUNING (Preserved)
# =========================================================
seperator
info "Start Doing System Tuning"

install_ tuned_ "Installing tuned" "/tmp/tuned_error" tuned_success
install_ set_txqueuelen_ "Setting txqueuelen" "/tmp/txqueuelen_error" txqueuelen_success
install_ set_file_open_limit_ "Setting File Open Limit" "/tmp/file_open_limit_error" file_open_limit_success

# Check for Virtual Environment
systemd-detect-virt > /dev/null
if [ $? -eq 0 ]; then
    warn "Virtualization detected, skipping Disk Scheduler tuning"
    install_ disable_tso_ "Disabling TSO" "/tmp/tso_error" tso_success
else
    install_ set_disk_scheduler_ "Setting Disk Scheduler" "/tmp/disk_scheduler_error" disk_scheduler_success
    install_ set_ring_buffer_ "Setting Ring Buffer" "/tmp/ring_buffer_error" ring_buffer_success
fi

install_ set_initial_congestion_window_ "Setting Initial Congestion Window" "/tmp/initial_congestion_window_error" initial_congestion_window_success
install_ kernel_settings_ "Setting Kernel Settings" "/tmp/kernel_settings_error" kernel_settings_success

# BBRv3
if [[ -n "$bbrv3_install" ]]; then
    install_ install_bbrv3_ "Installing BBRv3" "/tmp/bbrv3_error" bbrv3_install_success
fi

## Configure Boot Script
touch /root/.boot-script.sh && chmod +x /root/.boot-script.sh
cat << EOF > /root/.boot-script.sh
#!/bin/bash
sleep 120s
# Re-apply network settings on boot
/sbin/sysctl -p
/sbin/ethtool -G \$(ip route get 1 | awk '{print \$5; exit}') rx 4096 tx 4096 2>/dev/null
/sbin/ifconfig \$(ip route get 1 | awk '{print \$5; exit}') txqueuelen 10000
EOF

# Service for boot script
cat << EOF > /etc/systemd/system/boot-script.service
[Unit]
Description=boot-script
After=network.target

[Service]
Type=simple
ExecStart=/root/.boot-script.sh
RemainAfterExit=true

[Install]
WantedBy=multi-user.target
EOF
systemctl enable boot-script.service > /dev/null 2>&1

# =========================================================
#  5. FINAL SUMMARY
# =========================================================

# Detect IP
PUBLIC_IP=$(curl -s https://api.ipify.org || hostname -I | awk '{print $1}')

echo ""
echo -e "${GREEN}=====================================================${NC}"
echo -e "${GREEN}             INSTALLATION COMPLETE                   ${NC}"
echo -e "${GREEN}=====================================================${NC}"
echo ""

# Global Credentials
echo -e "   ${YELLOW}Credentials (Global)${NC}"
echo -e "   Username       : $username"
echo -e "   Password       : $password"
echo ""

# FileBrowser
if [[ -n "$fb_success" ]]; then
echo -e "   ${YELLOW}FileBrowser${NC}"
echo -e "   URL            : http://$PUBLIC_IP:808"
echo -e "   Status         : ${GREEN}Active${NC}"
echo ""
fi

# qBittorrent
if [[ -n "$qb_install_success" ]]; then
echo -e "   ${YELLOW}qBittorrent${NC}"
echo -e "   WebUI          : http://$PUBLIC_IP:$qb_port"
echo -e "   Cache          : $qb_cache MiB"
echo ""
fi

# Autobrr
if [[ -n "$autobrr_install_success" ]]; then
echo -e "   ${YELLOW}Autobrr${NC}"
echo -e "   WebUI          : http://$PUBLIC_IP:$autobrr_port" # Port is dynamic in original, usually 7474
echo ""
fi

# Vertex
if [[ -n "$vertex_install_success" ]]; then
echo -e "   ${YELLOW}Vertex${NC}"
echo -e "   WebUI          : http://$PUBLIC_IP:$vertex_port"
echo ""
fi

# BBR
if [[ -n "$bbrv3_install_success" ]]; then
echo -e "   ${YELLOW}Network Tuning${NC}"
echo -e "   BBRv3          : ${GREEN}Installed (Reboot required)${NC}"
echo ""
fi

echo -e "   ${YELLOW}Extra Tools${NC}    : mkbrr, mkvtoolnix, fastfetch, ffmpeg"
echo -e "   ${YELLOW}Torrent Script${NC} : /root/main.py"
echo ""
echo -e "${GREEN}=====================================================${NC}"
echo -e "Logs saved to: $LOG_FILE"
echo ""

exit 0
