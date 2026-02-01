# CCTV Server Kurulum Rehberi

go2rtc kullanarak CCTV kameralarını HLS/WebRTC stream olarak yayınlamanızı sağlar.

## 🖥️ Desteklenen Sistemler

- **Raspberry Pi** (3/4/5) - Raspberry Pi OS
- **AlmaLinux** / RHEL / CentOS Stream 9

---

## 🚀 Hızlı Kurulum

### Raspberry Pi
```bash
curl -sSL https://raw.githubusercontent.com/rootcastleco/raspberry-server/main/install.sh | bash
```

### AlmaLinux / RHEL 9
```bash
curl -sSL https://raw.githubusercontent.com/rootcastleco/raspberry-server/main/install-almalinux.sh | sudo bash
```

---

## 🛠️ Gereksinimler (Raspberry Pi)

- Raspberry Pi 3/4/5 (önerilen: Pi 4 2GB+)
- Raspberry Pi OS (64-bit önerilir)
- İnternet bağlantısı
- RTSP destekli IP kameralar

## 📦 Hızlı Kurulum

SSH ile Raspberry Pi'ye bağlanın ve aşağıdaki komutları sırayla çalıştırın:

### 1. Sistemi Güncelle
```bash
sudo apt update && sudo apt upgrade -y
```

### 2. FFmpeg Kur
```bash
sudo apt install ffmpeg -y
ffmpeg -version
```

### 3. go2rtc İndir ve Kur
```bash
# Klasör oluştur
sudo mkdir -p /opt/go2rtc
cd /opt/go2rtc

# Raspberry Pi için ARM64 sürümünü indir
sudo wget https://github.com/AlexxIT/go2rtc/releases/latest/download/go2rtc_linux_arm64

# Çalıştırılabilir yap
sudo mv go2rtc_linux_arm64 go2rtc
sudo chmod +x go2rtc
```

> **Not:** Raspberry Pi 3 veya 32-bit OS kullanıyorsanız `go2rtc_linux_arm` dosyasını indirin.

### 4. Yapılandırma Dosyası Oluştur
```bash
sudo nano /opt/go2rtc/config.yml
```

Aşağıdaki içeriği yapıştırın (kendi kamera bilgilerinizle değiştirin):
```yaml
streams:
  cam1: rtsp://admin:password@192.168.1.100:554/Streaming/Channels/101
  cam2: rtsp://admin:password@192.168.1.101:554/cam/realmonitor?channel=1&subtype=0

api:
  listen: ":1984"
  origin: "*"

webrtc:
  listen: ":8555/tcp"
```

Kaydetmek için: `Ctrl+X`, sonra `Y`, sonra `Enter`

### 5. Systemd Servisi Oluştur
```bash
sudo nano /etc/systemd/system/go2rtc.service
```

Aşağıdaki içeriği yapıştırın:
```ini
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
```

### 6. Servisi Başlat
```bash
sudo systemctl daemon-reload
sudo systemctl enable go2rtc
sudo systemctl start go2rtc
sudo systemctl status go2rtc
```

### 7. Firewall Ayarları
```bash
# UFW kullanıyorsanız
sudo ufw allow 1984/tcp
sudo ufw allow 8555/tcp
```

## ✅ Test Etme

Tarayıcıda şu adresi açın:
```
http://RASPBERRY_PI_IP:1984
```

go2rtc web arayüzü açılacak. Buradan:
- Kamera akışlarını görebilirsiniz
- HLS stream URL: `http://RASPBERRY_PI_IP:1984/api/stream.m3u8?src=cam1`
- WebRTC stream de desteklenir

## 🔧 Yararlı Komutlar

```bash
# Servis durumunu kontrol et
sudo systemctl status go2rtc

# Logları görüntüle
sudo journalctl -u go2rtc -f

# Servisi yeniden başlat
sudo systemctl restart go2rtc

# Yapılandırmayı düzenle
sudo nano /opt/go2rtc/config.yml
```

## 📹 Kamera Ekleme

Yeni kamera eklemek için `/opt/go2rtc/config.yml` dosyasını düzenleyin:

```yaml
streams:
  cam1: rtsp://admin:password@192.168.1.100:554/stream
  cam2: rtsp://admin:password@192.168.1.101:554/stream
  cam3: rtsp://admin:password@192.168.1.102:554/stream  # Yeni kamera
```

Sonra servisi yeniden başlatın:
```bash
sudo systemctl restart go2rtc
```

## 🚨 Sorun Giderme

| Sorun | Çözüm |
|-------|-------|
| Kamera görüntüsü yok | RTSP URL'ini VLC ile test edin |
| Port erişilemiyor | Firewall ayarlarını kontrol edin |
| Servis başlamıyor | `journalctl -u go2rtc` ile logları inceleyin |
| Yüksek CPU kullanımı | Kamera stream kalitesini düşürün |

## 📄 Lisans

MIT License
