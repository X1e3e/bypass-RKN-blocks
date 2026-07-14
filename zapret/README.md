# ⚡ Локальный обход DPI (Zapret, GoodbyeDPI, SpoofDPI)

Обход систем глубокого анализа пакетов (DPI) позволяет восстановить доступ к YouTube, Discord и другим заблокированным ресурсам без использования внешних VPN/прокси серверов. Трафик не шифруется и идет напрямую к серверам (например, Google Video), обеспечивая максимальную скорость и минимальный пинг.

---

## 💻 Windows (GoodbyeDPI)
Для ОС Windows лучшим решением является **GoodbyeDPI** от ValdikSS.

### Установка и настройка:
1. Скачайте последнюю версию архива `goodbyedpi-...-release.zip` с официального репозитория [ValdikSS/GoodbyeDPI](https://github.com/ValdikSS/GoodbyeDPI/releases).
2. Распакуйте архив в удобную папку (например, `C:\goodbyedpi`).
3. Для настройки обхода YouTube и Discord откройте текстовым редактором файл `service_install_russia_blacklist.cmd`.
4. Найдите строчку запуска службы `sc create "GoodbyeDPI" ...` и отредактируйте параметры запуска.
5. Запустите этот скрипт от имени Администратора для установки службы. Она будет автоматически запускаться при старте системы.

### Рекомендуемые параметры запуска (актуальные для YouTube и Discord в 2026 году):
Если стандартные пресеты (`-9`) не помогают, попробуйте следующий набор параметров:
```cmd
-e 1 -q --fake-gen 2 --fake-resend 2 --split-pos 3 --desync-ttl 3 --native-frag
```
*   `-e 1` — включить фрагментацию SNI.
*   `-q` — отключить повторные попытки при ошибках.
*   `--fake-gen 2 --fake-resend 2` — параметры генерации фейковых пакетов.
*   `--split-pos 3` — позиция деления TCP пакета.
*   `--desync-ttl 3` — TTL для обхода ТСПУ провайдеров.

*Готовый кастомный bat-файл лежит по пути: [`configs/windows_goodbyedpi_custom.bat`](./configs/windows_goodbyedpi_custom.bat).*

---

## 🍎 macOS (SpoofDPI)
Для macOS лучшим решением является **SpoofDPI** от xvzc.

### Установка:
Удобнее всего установить через менеджер пакетов Homebrew:
```bash
brew install xvzc/tap/spoofdpi
```

### Запуск:
По умолчанию запуск производится командой `spoofdpi`. Однако для лучшего обхода YouTube/Discord на провайдерах РФ рекомендуется использовать дополнительные параметры:
```bash
spoofdpi --enable-doh --window-size 30 --pattern "googlevideo.com|discord"
```
*   `--enable-doh` — использовать DNS over HTTPS (предотвращает подмену DNS).
*   `--window-size 30` — уменьшить размер TCP окна для дефрагментации трафика.
*   `--pattern` — применять обход только для указанных доменов (чтобы не ломать другие сайты).

*Скрипт для автоматического автозапуска (launchd) лежит по пути: [`configs/macos_spoofdpi_custom.sh`](./configs/macos_spoofdpi_custom.sh).*

---

## 🐧 Linux (zapret)
Оригинальный **zapret** от bol-van — мощнейший инструмент обхода DPI, работающий как демон на базе iptables/nftables.

### Установка:
1. Склонируйте репозиторий:
   ```bash
   git clone https://github.com/bol-van/zapret.git /opt/zapret
   ```
2. Перейдите в папку и запустите установщик:
   ```bash
   cd /opt/zapret && sudo ./install_easy.sh
   ```
3. Скрипт задаст вопросы о типе вашей сети, провайдере и установит необходимые пакеты (curl, nftables/iptables).
4. Во время установки выберите автоматическую настройку или настройте параметры вручную в файле `/etc/zapret/config`.

### Конфигурация (`/etc/zapret/config`):
Для обхода ТСПУ и восстановления YouTube отредактируйте параметры `NFQWS_OPT_DESYNC` в конфигурационном файле:
```bash
NFQWS_OPT_DESYNC="--desync-mode=fake,disorder2 --desync-ttl=3 --desync-fooling=md5sig,badsum --desync-fake-http=../files/fake/fake_html.txt"
```
После изменения конфигурации перезапустите службу:
```bash
sudo systemctl restart zapret
```

---

## 🔌 Роутеры (Keenetic, OpenWrt)

Настройка обхода DPI прямо на роутере позволяет починить YouTube и Discord на всех домашних устройствах (включая Smart TV, консоли и мобильные телефоны).

### 🔷 Keenetic
На роутерах Keenetic это реализуется через установку пакета `zapret` в среду Entware:
1. Подключите USB-накопитель и установите систему пакетов **Entware** (официальная инструкция Keenetic).
2. Подключитесь к роутеру по SSH (порт 222) и обновите пакеты:
   ```bash
   opkg update
   opkg install zapret
   ```
3. Отредактируйте конфигурационный файл `/opt/etc/zapret/config` в соответствии со стратегией вашего провайдера.
4. Включите автозапуск:
   ```bash
   /opt/etc/init.d/S51zapret start
   ```

### 🟩 OpenWrt
Роутеры на OpenWrt идеально подходят для zapret из-за нативной поддержки iptables/nftables и низких требований к процессору.
1. Обновите репозитории и установите зависимости:
   ```bash
   opkg update
   opkg install git-http ca-bundle ca-certificates
   ```
2. Скачайте скрипты zapret:
   ```bash
   git clone --depth=1 https://github.com/bol-van/zapret.git /tmp/zapret
   cd /tmp/zapret
   ./install_easy.sh
   ```
3. Установщик автоматически настроит правила брандмауэра `firewall4` (nftables) или `firewall3` (iptables).
4. Настройте список доменов обхода (например, внесите туда только `googlevideo.com`, `youtube.com` и `discord.com`), чтобы не нагружать слабый процессор роутера разбором всего трафика.
