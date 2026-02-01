#!/bin/bash
# AlmaLinux 9.6 CCTV Server Installation Script
# Usage: curl -sSL https://raw.githubusercontent.com/rootcastleco/raspberry-server/main/install-almalinux.sh | bash
set -e

echo "=========================================="
echo "  AlmaLinux CCTV Server Installation"
echo "=========================================="

# Color codes
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Check if running as root or with sudo
if [ "$EUID" -ne 0 ]; then 
    echo -e "${RED}Please run as root or with sudo${NC}"
    exit 1
fi

# 1. System Update
echo -e "${YELLOW}[1/7] Updating system...${NC}"
dnf update -y

# 2. Enable EPEL and RPM Fusion repositories
echo -e "${YELLOW}[2/7] Enabling EPEL and RPM Fusion repositories...${NC}"
dnf install -y epel-release
dnf config-manager --set-enabled crb

# RPM Fusion for FFmpeg
dnf install -y --nogpgcheck https://mirrors.rpmfusion.org/free/el/rpmfusion-free-release-$(rpm -E %rhel).noarch.rpm 2>/dev/null || true

# 3. FFmpeg Installation
echo -e "${YELLOW}[3/7] Installing FFmpeg...${NC}"
dnf install -y ffmpeg

# 4. Download go2rtc
echo -e "${YELLOW}[4/7] Downloading go2rtc...${NC}"
mkdir -p /opt/go2rtc
cd /opt/go2rtc

# Detect architecture
ARCH=$(uname -m)
if [ "$ARCH" = "x86_64" ]; then
    GO2RTC_FILE="go2rtc_linux_amd64"
elif [ "$ARCH" = "aarch64" ]; then
    GO2RTC_FILE="go2rtc_linux_arm64"
elif [ "$ARCH" = "armv7l" ]; then
    GO2RTC_FILE="go2rtc_linux_arm"
else
    echo -e "${RED}Unsupported architecture: $ARCH${NC}"
    exit 1
fi

wget -q "https://github.com/AlexxIT/go2rtc/releases/latest/download/${GO2RTC_FILE}" -O go2rtc
chmod +x go2rtc

# 5. Create Default Configuration
echo -e "${YELLOW}[5/7] Creating configuration file...${NC}"
if [ ! -f /opt/go2rtc/config.yml ]; then
    cat > /opt/go2rtc/config.yml <<EOF
# go2rtc Configuration
# Add your camera RTSP URLs here

streams:
  # Example cameras - replace with your own credentials
  # cam1: rtsp://admin:password@192.168.1.100:554/Streaming/Channels/101
  # cam2: rtsp://admin:password@192.168.1.101:554/stream

api:
  listen: ":1984"
  origin: "*"

webrtc:
  listen: ":8555/tcp"

log:
  level: info
EOF
fi

# 6. Create Systemd Service
echo -e "${YELLOW}[6/7] Creating systemd service...${NC}"
cat > /etc/systemd/system/go2rtc.service <<EOF
[Unit]
Description=go2rtc RTSP to HLS Converter
After=network.target

[Service]
Type=simple
ExecStart=/opt/go2rtc/go2rtc -c /opt/go2rtc/config.yml
Restart=always
RestartSec=5
User=root
WorkingDirectory=/opt/go2rtc

# Security hardening
NoNewPrivileges=true
PrivateTmp=true

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable go2rtc
systemctl start go2rtc

# 7. Firewall Configuration
echo -e "${YELLOW}[7/7] Configuring firewall...${NC}"
if command -v firewall-cmd &> /dev/null; then
    firewall-cmd --permanent --add-port=1984/tcp 2>/dev/null || true
    firewall-cmd --permanent --add-port=8555/tcp 2>/dev/null || true
    firewall-cmd --reload 2>/dev/null || true
    echo -e "${GREEN}Firewall rules added${NC}"
fi

# Check SELinux and provide instructions
if command -v getenforce &> /dev/null; then
    SELINUX_STATUS=$(getenforce)
    if [ "$SELINUX_STATUS" = "Enforcing" ]; then
        echo -e "${YELLOW}SELinux is enforcing. Configuring policy...${NC}"
        # Allow go2rtc to bind to the required ports
        semanage port -a -t http_port_t -p tcp 1984 2>/dev/null || semanage port -m -t http_port_t -p tcp 1984
        semanage port -a -t http_port_t -p tcp 8555 2>/dev/null || semanage port -m -t http_port_t -p tcp 8555
    fi
fi

# Get server IP
SERVER_IP=$(hostname -I | awk '{print $1}')

# Completion
echo ""
echo -e "${GREEN}=========================================="
echo "  Installation Complete!"
echo "==========================================${NC}"
echo ""
echo "Server IP Address: $SERVER_IP"
echo ""
echo "Web Interface: http://$SERVER_IP:1984"
echo ""
echo "Next steps:"
echo "  1. Add your cameras: nano /opt/go2rtc/config.yml"
echo "  2. Restart service: systemctl restart go2rtc"
echo "  3. Check status: systemctl status go2rtc"
echo "  4. View logs: journalctl -u go2rtc -f"
echo ""
echo "Useful commands:"
echo "  - Test go2rtc: /opt/go2rtc/go2rtc -c /opt/go2rtc/config.yml"
echo "  - Check firewall: firewall-cmd --list-all"
echo "  - Check SELinux: getenforce"
echo ""
