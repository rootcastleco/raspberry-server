#!/bin/bash
# Frigate NVR + go2rtc Installation Script
# Supports: Debian/Ubuntu, AlmaLinux/RHEL/CentOS
# go2rtc: port 1984 (canlı yayın)
# Frigate: port 5000 (kayıt + hareket algılama)
# Usage: curl -sSL https://raw.githubusercontent.com/rootcastleco/raspberry-server/main/install-frigate.sh | sudo bash

set -e

echo "=========================================="
echo "  Frigate NVR + go2rtc Kurulumu"
echo "=========================================="

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

if [ "$EUID" -ne 0 ]; then 
    echo -e "${RED}Lütfen root olarak veya sudo ile çalıştırın${NC}"
    exit 1
fi

# Detect OS
if command -v apt &> /dev/null; then
    PKG_MANAGER="apt"
    echo -e "${YELLOW}Debian/Ubuntu tespit edildi${NC}"
elif command -v dnf &> /dev/null; then
    PKG_MANAGER="dnf"
    echo -e "${YELLOW}RHEL/AlmaLinux tespit edildi${NC}"
elif command -v yum &> /dev/null; then
    PKG_MANAGER="yum"
    echo -e "${YELLOW}CentOS tespit edildi${NC}"
else
    echo -e "${RED}Desteklenmeyen paket yöneticisi${NC}"
    exit 1
fi

# 1. Docker Kurulumu
echo -e "${YELLOW}[1/6] Docker kuruluyor...${NC}"
if ! command -v docker &> /dev/null; then
    if [ "$PKG_MANAGER" = "apt" ]; then
        apt update
        apt install -y apt-transport-https ca-certificates curl gnupg lsb-release
        curl -fsSL https://download.docker.com/linux/$(. /etc/os-release && echo "$ID")/gpg | gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
        echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/$(. /etc/os-release && echo "$ID") $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null
        apt update
        apt install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin
    else
        $PKG_MANAGER install -y dnf-plugins-core 2>/dev/null || true
        $PKG_MANAGER config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo 2>/dev/null || true
        $PKG_MANAGER install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin
    fi
    systemctl enable --now docker
else
    echo "Docker zaten kurulu"
fi

# 2. go2rtc Kurulumu (mevcut değilse)
echo -e "${YELLOW}[2/6] go2rtc kontrol ediliyor...${NC}"
if [ ! -f /opt/go2rtc/go2rtc ]; then
    echo "go2rtc kuruluyor..."
    mkdir -p /opt/go2rtc
    cd /opt/go2rtc
    
    ARCH=$(uname -m)
    if [ "$ARCH" = "x86_64" ]; then
        GO2RTC_FILE="go2rtc_linux_amd64"
    elif [ "$ARCH" = "aarch64" ]; then
        GO2RTC_FILE="go2rtc_linux_arm64"
    else
        GO2RTC_FILE="go2rtc_linux_arm"
    fi
    
    wget -q "https://github.com/AlexxIT/go2rtc/releases/latest/download/${GO2RTC_FILE}" -O go2rtc
    chmod +x go2rtc
    
    # go2rtc config
    cat > /opt/go2rtc/config.yml <<EOF
streams:
  # Kameralarınızı buraya ekleyin
  # cam1: rtsp://admin:password@192.168.1.100:554/live/0/MAIN

api:
  listen: ":1984"
  origin: "*"
  # Güvenlik için username/password ekleyin
  # username: "admin"
  # password: "sifre123"

webrtc:
  listen: ":8555/tcp"
EOF
    
    # go2rtc systemd service
    cat > /etc/systemd/system/go2rtc.service <<EOF
[Unit]
Description=go2rtc RTSP to HLS Converter
After=network.target

[Service]
ExecStart=/opt/go2rtc/go2rtc -c /opt/go2rtc/config.yml
Restart=always
User=root
WorkingDirectory=/opt/go2rtc

[Install]
WantedBy=multi-user.target
EOF
    
    systemctl daemon-reload
    systemctl enable go2rtc
    systemctl start go2rtc
else
    echo "go2rtc zaten kurulu"
fi

# 3. Frigate Klasörleri
echo -e "${YELLOW}[3/6] Frigate klasörleri oluşturuluyor...${NC}"
mkdir -p /opt/frigate/config
mkdir -p /opt/frigate/media

# 4. Frigate Config
echo -e "${YELLOW}[4/6] Frigate yapılandırması oluşturuluyor...${NC}"
cat > /opt/frigate/config/config.yml <<EOF
mqtt:
  enabled: false

# Frigate kendi go2rtc'sini kullanır (port 8554)
go2rtc:
  streams:
    # Kameralarınızı buraya ekleyin
    # cam1: rtsp://admin:password@192.168.1.100:554/live/0/MAIN
    # cam2: dvrip://admin:password@192.168.1.101:34567?channel=0&subtype=0

cameras:
  # Örnek kamera - kendi bilgilerinizle değiştirin
  # cam1:
  #   ffmpeg:
  #     inputs:
  #       - path: rtsp://127.0.0.1:8554/cam1
  #         roles:
  #           - detect
  #           - record
  #   detect:
  #     enabled: true
  #     width: 1280
  #     height: 720
  #   record:
  #     enabled: true
  #     retain:
  #       days: 7

# Kayıt ayarları
record:
  enabled: true
  retain:
    days: 7
    mode: motion  # Sadece hareket olduğunda kaydet

# Snapshot ayarları  
snapshots:
  enabled: true
  retain:
    default: 7
EOF

# 5. Frigate Docker Container
echo -e "${YELLOW}[5/6] Frigate başlatılıyor...${NC}"
docker stop frigate 2>/dev/null || true
docker rm frigate 2>/dev/null || true

docker run -d \
  --name frigate \
  --restart=unless-stopped \
  --shm-size=256m \
  -v /opt/frigate/config:/config \
  -v /opt/frigate/media:/media/frigate \
  -v /etc/localtime:/etc/localtime:ro \
  -p 5000:5000 \
  -p 8554:8554 \
  -p 8555:8555/tcp \
  ghcr.io/blakeblackshear/frigate:stable

# 6. Firewall
echo -e "${YELLOW}[6/6] Firewall ayarları...${NC}"
if command -v firewall-cmd &> /dev/null; then
    firewall-cmd --permanent --add-port=1984/tcp 2>/dev/null || true   # go2rtc
    firewall-cmd --permanent --add-port=5000/tcp 2>/dev/null || true   # Frigate web
    firewall-cmd --permanent --add-port=8554/tcp 2>/dev/null || true   # Frigate RTSP
    firewall-cmd --permanent --add-port=8555/tcp 2>/dev/null || true   # Frigate WebRTC
    firewall-cmd --reload 2>/dev/null || true
fi

# IP adresi al
SERVER_IP=$(hostname -I | awk '{print $1}')

echo ""
echo -e "${GREEN}=========================================="
echo "  Kurulum Tamamlandı!"
echo "==========================================${NC}"
echo ""
echo "Sunucu IP: $SERVER_IP"
echo ""
echo "┌─────────────────────────────────────────┐"
echo "│  Servis        │  Port  │  Adres        │"
echo "├─────────────────────────────────────────┤"
echo "│  go2rtc        │  1984  │  Canlı Yayın  │"
echo "│  Frigate       │  5000  │  NVR + Kayıt  │"
echo "└─────────────────────────────────────────┘"
echo ""
echo "Web Arayüzleri:"
echo "  go2rtc:  http://$SERVER_IP:1984"
echo "  Frigate: http://$SERVER_IP:5000"
echo ""
echo "Sonraki adımlar:"
echo "  1. go2rtc kameralarını ekle: nano /opt/go2rtc/config.yml"
echo "  2. Frigate kameralarını ekle: nano /opt/frigate/config/config.yml"
echo "  3. Servisleri yeniden başlat:"
echo "     - systemctl restart go2rtc"
echo "     - docker restart frigate"
echo ""
echo "Yararlı komutlar:"
echo "  - Frigate logları: docker logs -f frigate"
echo "  - go2rtc logları: journalctl -u go2rtc -f"
echo ""
