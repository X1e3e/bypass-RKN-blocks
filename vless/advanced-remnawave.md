# ⚙️ Продвинутая настройка и администрирование Remnawave

В данном руководстве собраны проверенные практические инструкции по тонкой настройке панели управления Remnawave, оптимизации Xray нод, обходу жестких блокировок и устранению известных ошибок совместимости.

---

## 1. 🛡️ Развертывание Remnawave Reverse Proxy

Использование реверс-прокси перед панелью необходимо для защиты веб-интерфейса, управления SSL-сертификатами и оптимизации маршрутизации API.

### Автоматическая установка через скрипт
Для развертывания преднастроенного стека с реверс-прокси выполните команду на сервере панели:
```bash
bash <(wget -qO- https://raw.githubusercontent.com/eGamesAPI/remnawave-reverse-proxy/refs/heads/main/install_remnawave.sh)
```
*Если на сервере возникают проблемы со скачиванием через wget, используйте альтернативный запуск с логированием процесса установки в файл:*
```bash
bash -x <(curl -4 -Ls https://raw.githubusercontent.com/eGamesAPI/remnawave-reverse-proxy/refs/heads/main/install_remnawave.sh | sed 's/wget -q -O/curl -4 -Ls -o/g') 2>&1 | tee install.log
```

### Nginx vs Caddy (Проблема с сокетами)
*   **Симптом:** При использовании Nginx в качестве реверс-прокси перед Xray нодами в логах контейнера Nginx (`docker logs remnawave-nginx`) возникают частые ошибки обрыва сокетов (`connection reset`).
*   **Причина:** Несовместимость буферизации сокетов в Nginx с механизмами кастомного ядра Xray, обрабатывающего прокси-соединения.
*   **Решение:** Использование веб-сервера **Caddy**. Caddy из коробки корректно обрабатывает websocket/xhttp соединения без разрывов сессий. Если вы используете Nginx и сталкиваетесь с падением производительности, переключите реверс-прокси на Caddy.

### Баг авторизации OAuth в Remnawave v2.7.4
*   **Симптом:** При попытке авторизации в панели через GitHub или Яндекс-аккаунты после редиректа на страницу `/oauth2/callback/github` (или `/yandex`) возникает ошибка соединения `ERR_CONNECTION_RESET`. При этом Telegram OAuth работает стабильно.
*   **Решение:**
    1. Проверьте правильность URL-адреса обратного вызова (Callback URL) в настройках OAuth-приложений на стороне GitHub/Яндекс (он должен строго совпадать с внешним HTTPS-доменом вашей панели).
    2. Убедитесь, что в переменных окружения панели (`.env` файл) корректно настроен массив разрешенных email-адресов.
    3. При сохранении ошибки переведите авторизацию на Telegram OAuth либо откатите образ панели до стабильной версии 2.7.2.

---

## 2. 🛠️ Ручное обновление ядра Xray в RemnaNode

В нодах Remnawave версии **2.7.0** (использующих ядро Xray **26.3.27**) присутствует критический баг: при подключении по протоколу Hysteria 2 панель не отображает пользователя в онлайне и **не считает его трафик**. 

Для исправления бага необходимо вручную обновить ядро Xray внутри Docker-контейнера ноды до стабильной версии **26.6.1** или выше.

### Пошаговая инструкция обновления:

1.  Подключитесь к VPS с установленной Xray-нодой по SSH.
2.  Создайте директорию для нового ядра и перейдите в нее:
    ```bash
    mkdir -p /opt/remnanode/custom-xray && cd /opt/remnanode/custom-xray
    ```
3.  Установите утилиту `unzip` (если она отсутствует в системе):
    ```bash
    apt update && apt install wget unzip -y
    ```
4.  Скачайте архив Xray-core нужной версии (например, v26.6.1):
    ```bash
    wget https://github.com/XTLS/Xray-core/releases/download/v26.6.1/Xray-linux-64.zip
    ```
5.  Распакуйте скачанный архив:
    ```bash
    unzip -o Xray-linux-64.zip
    ```
6.  Откройте файл конфигурации Docker Compose ноды в текстовом редакторе:
    ```bash
    nano /opt/remnanode/docker-compose.yml
    ```
7.  В секции `volumes` контейнера ноды прокиньте путь к новому бинарному файлу xray:
    ```yaml
    volumes:
      - '/opt/remnanode/custom-xray/xray:/usr/local/bin/xray:ro'
    ```
8.  Перезапустите контейнеры ноды для применения нового ядра:
    ```bash
    cd /opt/remnanode
    docker compose down
    docker compose up -d
    ```
9.  Убедитесь, что нода запустилась с новым ядром, проверив версию Xray:
    ```bash
    docker exec -it remnanode xray version
    ```
    *(В выводе должна отобразиться версия Xray v26.6.1).*

---

## 3. 🛰️ Настройка обхода Белых Списков (БС) через CDN

В режиме «Белых Списков» прямые Reality-соединения до зарубежных серверов блокируются. Трафик необходимо направлять через разрешенные отечественные CDN (Yandex Cloud CDN, Selectel CDN, Beeline CDN).

### Использование Beeline CDN (Бесплатный безлимит)
Некоторые типы корпоративных аккаунтов Beeline CDN предоставляют безлимитный бесплатный трафик. Это позволяет направлять через них трафик пользователей без финансовых затрат на оплату гигабайт. Конфигурация через Beeline CDN стабильно работает в клиентах Happ и Incy и не требует постоянного сканирования рабочих EDGE IP-адресов.

### Тонкая настройка обфускации фреймов (xPadding в xhttp)
Транспорт `xhttp` имитирует обычные REST API запросы (загрузка файлов методом POST и скачивание методом GET). Чтобы ТСПУ/DPI не заблокировал CDN-трафик на основе анализа размеров пакетов (фреймов), настраивается случайное заполнение пакетов мусорными байтами (`xPadding`).

Пример конфигурации входящего потока (`inbound`) Xray с использованием обфускации `xPadding` в заголовке `X-Cache`:
```json
{
  "tag": "in-cdn-xhttp",
  "port": 8003,
  "listen": "127.0.0.1",
  "protocol": "vless",
  "settings": {
    "clients": [
      {
        "id": "ВАШ_UUID"
      }
    ],
    "decryption": "none"
  },
  "streamSettings": {
    "network": "xhttp",
    "security": "none",
    "xhttpSettings": {
      "mode": "packet-up",
      "path": "/api-vless-cdn",
      "xPaddingObfsMode": true,
      "xPaddingKey": "your_obfuscation_key",
      "xPaddingHeader": "X-Cache",
      "xPaddingMethod": "tokenish",
      "xPaddingPlacement": "queryInHeader"
    }
  }
}
```

### Устранение утечек DNS в клиенте Incy
При использовании CDN-нод в клиенте Incy могут возникать утечки DNS (запросы к заблокированным сайтам уходят мимо прокси). 
*   **Решение:** Полностью удалите секцию `"dns"` из клиентской конфигурации Xray JSON. Это принудительно заставит клиент маршрутизировать абсолютно все DNS-запросы через прокси-туннель.

---

## 4. 🏢 Рекомендации по выбору хостинга под VPN ноды

### Выделенные мобильные IP-адреса (МТС Веб-Сервисы / MWS)
*   Адреса из подсетей `176.109.92.0/24`, `176.109.94.0/24`, `176.109.85.0/24` и приватной зоны `176.109.82.0/24` определяются ТСПУ как мобильная сотовая сеть МТС/Yota.
*   Трафик к этим подсетям не режется и не блокируется даже при жестких фильтрах. При аренде MWS рекомендуется запрашивать выдачу IP-адресов именно из этих диапазонов.

### Оптимизация зарубежного трафика на Aeza RU
*   При покупке VPS в РФ от Aeza (Ryzen 9 9950X, диапазон IP: `83.147.255.0/24`) для использования в качестве транзитного прокси, доступ к заблокированным ресурсам на самом сервере настраивается через Cloudflare Warp.
*   Утилита `warp-native` ставится на сервера Aeza с локацией в РФ без ошибок и обеспечивает стабильный транзит трафика за рубеж.

---

## 5. 🛠️ Диагностика, тестирование и обслуживание системы

Ниже собраны основные терминальные команды и процедуры для администрирования, тестирования и траблшутинга серверов.

### 📶 Отключение IPv6 на хост-серверах (Лечение таймаутов)
Многие российские хостинги имеют некорректную маршрутизацию IPv6, что вызывает задержки при установлении соединений (таймауты) в Xray/Reality. Для полного отключения IPv6 на VPS выполните:
```bash
cat << 'EOF' > /etc/sysctl.d/99-disable-ipv6.conf
net.ipv6.conf.all.disable_ipv6 = 1
net.ipv6.conf.default.disable_ipv6 = 1
net.ipv6.conf.lo.disable_ipv6 = 1
EOF
sysctl -p /etc/sysctl.d/99-disable-ipv6.conf
sed -i 's/GRUB_CMDLINE_LINUX_DEFAULT="/&ipv6.disable=1 /' /etc/default/grub
update-grub
sed -i 's/#AddressFamily any/AddressFamily inet/' /etc/ssh/sshd_config
systemctl restart ssh
```

### 🛰️ Проверка геолокации IP-адреса сервером Google
Для проверки, под какой страной Google видит ваш сервер (важно для проверки работы Warp-маршрутизации и обхода региональных ограничений):
```bash
curl -4 -s --user-agent "Mozilla/5.0 (X11; Linux x86_64; rv:130.0) Gecko/20100101 Firefox/130.0" https://www.google.com | sed -n 's/.*"[a-z]\{2\}_\([A-Z]\{2\}\)".*/\1/p'
```
*(Команда вернет двухбуквенный код страны, например: `US`, `DE`, `NL`)*.

### 🌐 Базовая проверка доступности порта и TLS-рукопожатия ноды
Для проверки успешного прохождения TCP-соединения и сверки SSL-сертификата (позволяет быстро локализовать блокировку порта на ТСПУ без отправки mTLS ключей Remnawave):
```bash
curl -v --connect-timeout 5 https://<IP_АДРЕС_НОДЫ>:443 -k
```
> [!IMPORTANT]
> Сама нода Remnawave защищена mTLS, поэтому при обычном curl-запросе соединение должно выдавать ошибку SSL-рукопожатия со стороны сервера (это штатное поведение защиты от сканирования). Но эта команда подтверждает, что порт открыт и отвечает.

### 🔄 Обслуживание и обновление контейнеров панели
*   **Полное обновление панели и баз данных:**
    ```bash
    cd /opt/remnawave && docker compose pull && docker compose down && docker compose up -d && docker compose logs -f
    ```
*   **Обновление только страницы подписок (Subscription Page):**
    ```bash
    cd /opt/remnawave && docker compose pull remnawave-subscription-page && docker compose down remnawave-subscription-page && docker compose up -d remnawave-subscription-page && docker compose logs -f remnawave-subscription-page
    ```
*   **Обновление ноды (RemnaNode):**
    ```bash
    cd /opt/remnanode && docker compose pull && docker compose down && docker compose up -d && docker compose logs -f
    ```

### ⏰ Исправление зависания нод в Cron (SSL Renew Bug)
По умолчанию скрипты автоматической настройки реверс-прокси создают cron-задачу для еженедельного обновления SSL. В исходных скриптах используется грубая команда перезапуска:
`docker compose down && docker compose up`
Это приводит к полному отключению панели и всех нод каждое воскресенье в 5:00 утра.
*   **Исправление:** Откройте crontab (`crontab -e`) и замените полную остановку контейнеров на мягкий перезапуск веб-сервера Nginx/Caddy (без отключения бэкенда):
    ```cron
    0 5 * * 0 ufw allow 80 && /usr/bin/certbot renew --quiet && ufw delete allow 80 && ufw reload && cd /opt/remnawave && docker compose restart nginx
    ```

### 🔑 Тестирование API Remnawave (Добавление пользователя через curl)
Для ручной проверки работы API бэкенда панели или автоматизации выдачи ключей:
```bash
curl -X POST https://panel.yourdomain.com/api/users \
  -H "Cookie: Cookie=Cookie" \
  -H "Authorization: Bearer ВАШ_API_ТОКЕН" \
  -H "Content-Type: application/json" \
  -d '{
    "username": "TestUser",
    "uuid": "сгенерированный-uuid-клиента",
    "shortUuid": "короткий-id",
    "expireAt": "2026-12-31T23:59:59.999Z",
    "status": "ACTIVE",
    "trafficLimitBytes": 107374182400,
    "trafficLimitStrategy": "NO_RESET"
  }'
```
