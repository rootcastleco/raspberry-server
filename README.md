# 🎥 CCTV Server - go2rtc + Frigate NVR

IP kameralarınızı tek bir merkezden yönetin. Canlı yayın, kayıt ve hareket algılama özellikleri.

## 🖥️ Desteklenen Sistemler

| Sistem | Script |
|--------|--------|
| Raspberry Pi (Debian/Ubuntu) | `install.sh` |
| AlmaLinux / RHEL / CentOS 9 | `install-almalinux.sh` |
| Frigate NVR (Docker) | `install-frigate.sh` |

---

## 🚀 Hızlı Kurulum

### Raspberry Pi / Debian / Ubuntu

```bash
curl -sSL https://raw.githubusercontent.com/rootcastleco/raspberry-server/main/install.sh | sudo bash
```

### AlmaLinux / RHEL 9

```bash
curl -sSL https://raw.githubusercontent.com/rootcastleco/raspberry-server/main/install-almalinux.sh | sudo bash
```

### Frigate NVR + go2rtc (Docker)

```bash
curl -sSL https://raw.githubusercontent.com/rootcastleco/raspberry-server/main/install-frigate.sh | sudo bash
```

---

## 📦 Kurulum Sonrası

### Web Arayüzleri

| Servis | Port | Açıklama |
|--------|------|----------|
| go2rtc | 1984 | Canlı yayın (HLS/WebRTC) |
| Frigate | 5000 | NVR + Kayıt + Hareket Algılama |

### Erişim

- **go2rtc**: `http://SUNUCU_IP:1984`
- **Frigate**: `http://SUNUCU_IP:5000`

---

## 📹 Kamera Ekleme

### go2rtc Yapılandırması

```bash
sudo nano /opt/go2rtc/config.yml
```

```yaml
streams:
  # RTSP Kamera
  cam1: rtsp://admin:password@192.168.1.100:554/live/0/MAIN
  
  # XMeye/Hisilicon DVR
  cam2: dvrip://admin:password@192.168.1.101:34567?channel=0&subtype=0
  
  # ONVIF Kamera
  cam3: onvif://admin:password@192.168.1.102:80

api:
  listen: ":1984"
  origin: "*"
  # Güvenlik için şifre ekleyin
  username: "admin"
  password: "guclu_sifre_123"

webrtc:
  listen: ":8555/tcp"
```

```bash
sudo systemctl restart go2rtc
```

### Frigate Yapılandırması

```bash
sudo nano /opt/frigate/config/config.yml
```

```yaml
mqtt:
  enabled: false

go2rtc:
  streams:
    cam1: rtsp://admin:password@192.168.1.100:554/live/0/MAIN
    cam2: dvrip://admin:password@192.168.1.101:34567?channel=0&subtype=0

cameras:
  cam1:
    ffmpeg:
      inputs:
        - path: rtsp://127.0.0.1:8554/cam1
          roles:
            - detect
            - record
    detect:
      enabled: true
      width: 1280
      height: 720
    record:
      enabled: true
      retain:
        days: 7

  cam2:
    ffmpeg:
      inputs:
        - path: rtsp://127.0.0.1:8554/cam2
          roles:
            - detect
            - record
    detect:
      enabled: true
      width: 1280
      height: 720
    record:
      enabled: true
      retain:
        days: 7

record:
  enabled: true
  retain:
    days: 7
    mode: motion  # Sadece hareket olduğunda kaydet

snapshots:
  enabled: true
  retain:
    default: 7
```

```bash
sudo docker restart frigate
```

---

## 🔒 Güvenlik

### go2rtc Şifre Koruması

`/opt/go2rtc/config.yml` dosyasına ekleyin:

```yaml
api:
  listen: ":1984"
  username: "admin"
  password: "guclu_sifre_123"
```

### Firewall Ayarları

```bash
# UFW (Debian/Ubuntu)
sudo ufw allow 1984/tcp  # go2rtc
sudo ufw allow 5000/tcp  # Frigate

# firewalld (AlmaLinux/RHEL)
sudo firewall-cmd --permanent --add-port=1984/tcp
sudo firewall-cmd --permanent --add-port=5000/tcp
sudo firewall-cmd --reload
```

---

## 🔧 Yararlı Komutlar

### go2rtc

```bash
# Servis durumu
sudo systemctl status go2rtc

# Logları görüntüle
sudo journalctl -u go2rtc -f

# Yeniden başlat
sudo systemctl restart go2rtc

# Yapılandırmayı düzenle
sudo nano /opt/go2rtc/config.yml
```

### Frigate

```bash
# Container durumu
sudo docker ps

# Logları görüntüle
sudo docker logs -f frigate

# Yeniden başlat
sudo docker restart frigate

# Yapılandırmayı düzenle
sudo nano /opt/frigate/config/config.yml
```

---

## 📺 Desteklenen Kamera Protokolleri

| Protokol | Örnek URL | Açıklama |
|----------|-----------|----------|
| RTSP | `rtsp://user:pass@ip:554/stream` | Standart IP kamera |
| DVRIP | `dvrip://user:pass@ip:34567` | XMeye/Hisilicon DVR |
| ONVIF | `onvif://user:pass@ip:80` | ONVIF uyumlu kameralar |
| HTTP | `http://ip/video.mjpg` | MJPEG stream |
| RTMP | `rtmp://ip/live/stream` | RTMP stream |

---

## 🚨 Sorun Giderme

| Sorun | Çözüm |
|-------|-------|
| Stream not found | RTSP URL'ini VLC ile test edin |
| Port erişilemiyor | Firewall ayarlarını kontrol edin |
| Kamera bağlanmıyor | Kullanıcı adı/şifre doğru mu? |
| Yüksek CPU kullanımı | Substream kullanın (düşük kalite) |
| Docker başlamıyor | `sudo systemctl start docker` |

### Log Kontrolü

```bash
# go2rtc logları
sudo journalctl -u go2rtc --no-pager -n 50

# Frigate logları
sudo docker logs frigate --tail 50
```

---

## 📁 Dosya Yapısı

```
/opt/go2rtc/
├── go2rtc          # Çalıştırılabilir dosya
└── config.yml      # Yapılandırma

/opt/frigate/
├── config/
│   └── config.yml  # Frigate yapılandırması
└── media/          # Kayıtlar
```

---

## 📄 Lisans

MIT License

## 🤝 Katkıda Bulunma

Pull request'ler kabul edilir!

---

**Repo**: https://github.com/rootcastleco/raspberry-server
