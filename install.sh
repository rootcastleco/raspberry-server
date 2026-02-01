#!/bin/bash
# Raspberry Pi CCTV Server Kurulum Scripti
# Kullanım: curl -sSL https://raw.githubusercontent.com/rootcastleco/raspberry-server/main/install.sh | bash

set -e

echo "=========================================="
echo "  Raspberry Pi CCTV Server Kurulumu"
echo "=========================================="

# Renk kodları
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# 1. Sistem Güncellemesi
echo -e "${YELLOW}[1/6] Sistem güncelleniyor...${NC}"
sudo apt update && sudo apt upgrade -y

# 2. FFmpeg Kurulumu
echo -e "${YELLOW}[2/6] FFmpeg kuruluyor...${NC}"
sudo apt install ffmpeg -y

# 3. go2rtc İndirme
echo -e "${YELLOW}[3/6] go2rtc indiriliyor...${NC}"
sudo mkdir -p /opt/go2rtc
cd /opt/go2rtc

# ARM mimarisini tespit et
ARCH=$(uname -m)
if [ "$ARCH" = "aarch64" ]; then
    GO2RTC_FILE="go2rtc_linux_arm64"
elif [ "$ARCH" = "armv7l" ]; then
    GO2RTC_FILE="go2rtc_linux_arm"
else
    echo "Desteklenmeyen mimari: $ARCH"
    exit 1
fi

sudo wget -q "https://github.com/AlexxIT/go2rtc/releases/latest/download/${GO2RTC_FILE}" -O go2rtc
sudo chmod +x go2rtc

# 4. Varsayılan Yapılandırma
echo -e "${YELLOW}[4/6] Yapılandırma dosyası oluşturuluyor...${NC}"
if [ ! -f /opt/go2rtc/config.yml ]; then
    sudo tee /opt/go2rtc/config.yml > /dev/null <<EOF
# go2rtc Yapılandırması
# Kamera RTSP URL'lerinizi buraya ekleyin

streams:
  # Örnek kameralar - kendi bilgilerinizle değiştirin
  # cam1: rtsp://admin:password@192.168.1.100:554/Streaming/Channels/101
  # cam2: rtsp://admin:password@192.168.1.101:554/stream

api:
  listen: ":1984"
  origin: "*"

webrtc:
  listen: ":8555/tcp"
EOF
fi

# 5. Systemd Servisi
echo -e "${YELLOW}[5/6] Systemd servisi oluşturuluyor...${NC}"
sudo tee /etc/systemd/system/go2rtc.service > /dev/null <<EOF
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

sudo systemctl daemon-reload
sudo systemctl enable go2rtc
sudo systemctl start go2rtc

# 6. Firewall (eğer UFW kuruluysa)
echo -e "${YELLOW}[6/6] Firewall ayarları yapılıyor...${NC}"
if command -v ufw &> /dev/null; then
    sudo ufw allow 1984/tcp 2>/dev/null || true
    sudo ufw allow 8555/tcp 2>/dev/null || true
fi

# Tamamlandı
echo ""
echo -e "${GREEN}=========================================="
echo "  Kurulum Tamamlandı!"
echo "==========================================${NC}"
echo ""
echo "Raspberry Pi IP adresiniz: $(hostname -I | awk '{print $1}')"
echo ""
echo "Web Arayüzü: http://$(hostname -I | awk '{print $1}'):1984"
echo ""
echo "Sonraki adımlar:"
echo "  1. Kameralarınızı ekleyin: sudo nano /opt/go2rtc/config.yml"
echo "  2. Servisi yeniden başlatın: sudo systemctl restart go2rtc"
echo ""
