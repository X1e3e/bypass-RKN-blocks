# 🛰️ Обход «Белых Списков» (БС) через VLESS и CDN

**Режим «Белых Списков» (БС)** — это гипотетический или временно вводимый режим жесткой цензуры, при котором ТСПУ/DPI блокирует вообще весь входящий и исходящий зарубежный трафик, разрешая доступ только к ограниченному списку одобренных российских ресурсов (госуслуги, банки, национальные CDN, сайты госструктур). 

Обычные методы (VLESS-Reality, Hysteria 2, AmneziaWG) в этом режиме перестают работать, так как сервера VPS за границей блокируются по IP/геолокации независимо от используемого протокола маскировки.

Для обхода БС используется метод **транзитного проксирования (Relay)** через одобренные (входящие в белый список) российские облака, CDN-сети или транзитные VPS.

---

## 📐 Архитектура обхода БС

```
                       [ ВНУТРИ РФ ]                                 [ ВНЕ РФ ]
 Клиент  =======>  Российский транзит  =========================>  Выходная нода  ===> Заблокированный
(Телефон/ПК)    (CDN Yandex/Selectel/Beeline                  (VPS Германия/Польша)     сайт (Google)
                 или транзитный VPS в РФ)
            (Разрешено ТСПУ, так как IP в РФ)   (Разрешено как служебный трафик дата-центров)
```

---

## 🛠️ Основные методы обхода

### Метод 1. Российский транзитный сервер (RU Gateway)
Вы арендуете две VPS:
1.  **Транзитная VPS в РФ** (например, у RuVDS, FirstVDS, TimeWeb Cloud с локацией в Москве/СПб). ТСПУ разрешает вам доступ к ней, так как трафик не выходит за пределы РФ.
2.  **Выходная VPS за границей** (Германия, Нидерланды).
Клиент подключается к транзитному серверу в РФ, а тот пересылает трафик на выходной сервер за рубежом. Поскольку хостинг-провайдеры имеют служебные каналы связи с заграницей (BGP-линки), их трафик до зарубежных ДЦ часто не блокируется ТСПУ даже в режиме БС.

### Метод 2. CDN-фронтинг через российские CDN
Самый надежный и быстрый способ. Вы используете российские CDN-сервисы в качестве "щита":
*   **Поддерживаемые CDN:** Yandex Cloud CDN, Selectel CDN, VK Cloud, Beeline CDN (многие предоставляют безлимитный бесплатный трафик или тестовые балансы).
*   Вы настраиваете CDN так, чтобы его точкой истока (Origin) был ваш зарубежный VPS с установленным Xray.
*   Клиент подключается к домену CDN (который 100% находится в белом списке и имеет российские IP). CDN принимает трафик и пересылает его на ваш зарубежный сервер.

---

## 🚀 Протокол VLESS + xhttp (Новый стандарт Xray)

Для прохождения через CDN больше нельзя использовать старый протокол WebSocket (WS), так как он легко детектируется ТСПУ по специфическому HTTP-запросу `Upgrade: websocket`.

В новых версиях **Xray-core (v26.x.x+)** представлен новый транспорт **`xhttp`** (наследник WebSocket). Он имитирует стандартные REST API запросы (загрузка файлов методом POST и скачивание методом GET), что делает прокси-трафик неотличимым от работы обычного веб-приложения за CDN.

---

## 📋 Конфигурации Xray для настройки обхода БС

Ниже представлены рабочие шаблоны конфигураций, собранные на основе опыта инженеров сообщества *Bedolaga Social Club*.

### 1. Конфигурация транзитного (RU) сервера Xray
Устанавливается на сервере внутри РФ. Он принимает трафик от клиентов по протоколу `xhttp` на локальный порт и пересылает его в зашифрованный туннель Reality на зарубежный сервер.

```json
{
  "log": {
    "loglevel": "info"
  },
  "inbounds": [
    {
      "tag": "IN_FROM_CLIENTS_XHTTP",
      "listen": "0.0.0.0",
      "port": 443,
      "protocol": "vless",
      "settings": {
        "clients": [
          {
            "id": "ВАШ_UUID_ПОЛЬЗОВАТЕЛЯ"
          }
        ],
        "decryption": "none"
      },
      "streamSettings": {
        "network": "xhttp",
        "security": "none",
        "xhttpSettings": {
          "host": "your-transit-domain.ru",
          "path": "/api-endpoint",
          "mode": "auto"
        }
      }
    }
  ],
  "outbounds": [
    {
      "tag": "OUT_TO_FOREIGN_EXIT",
      "protocol": "vless",
      "settings": {
        "vnext": [
          {
            "address": "IP_ЗАРУБЕЖНОЙ_ВЫХОДНОЙ_НОДЫ",
            "port": 443,
            "users": [
              {
                "id": "ВАШ_UUID_ПОЛЬЗОВАТЕЛЯ",
                "encryption": "none",
                "flow": "xtls-rprx-vision"
              }
            ]
          }
        ]
      },
      "streamSettings": {
        "network": "tcp",
        "security": "reality",
        "realitySettings": {
          "serverName": "images.apple.com",
          "fingerprint": "chrome",
          "publicKey": "ПУБЛИЧНЫЙ_КЛЮЧ_ВЫХОДНОЙ_НОДЫ",
          "shortId": "SHORT_ID_ВЫХОДНОЙ_НОДЫ"
        }
      }
    },
    {
      "tag": "DIRECT",
      "protocol": "freedom"
    },
    {
      "tag": "BLOCK",
      "protocol": "blackhole"
    }
  ],
  "routing": {
    "rules": [
      {
        "type": "field",
        "inboundTag": [
          "IN_FROM_CLIENTS_XHTTP"
        ],
        "outboundTag": "OUT_TO_FOREIGN_EXIT"
      },
      {
        "type": "field",
        "ip": [
          "geoip:private"
        ],
        "outboundTag": "BLOCK"
      }
    ]
  }
}
```

---

### 2. Конфигурация выходного (Зарубежного) сервера Xray
Устанавливается на сервере за границей. Он принимает зашифрованный Reality-трафик от транзитного сервера и выпускает его в свободный интернет.

```json
{
  "log": {
    "loglevel": "warning"
  },
  "inbounds": [
    {
      "tag": "IN_REALITY_FROM_RU",
      "port": 443,
      "protocol": "vless",
      "settings": {
        "clients": [
          {
            "id": "ВАШ_UUID_ПОЛЬЗОВАТЕЛЯ",
            "flow": "xtls-rprx-vision"
          }
        ],
        "decryption": "none"
      },
      "streamSettings": {
        "network": "tcp",
        "security": "reality",
        "realitySettings": {
          "target": "images.apple.com:443",
          "serverNames": [
            "images.apple.com"
          ],
          "privateKey": "ВАШ_ПРИВАТНЫЙ_КЛЮЧ_REALITY",
          "shortIds": [
            "ВАШ_SHORT_ID"
          ],
          "fingerprint": "chrome"
        }
      }
    }
  ],
  "outbounds": [
    {
      "protocol": "freedom",
      "tag": "DIRECT"
    }
  ]
}
```

---

### 3. Конфигурация Xray для работы через CDN (с обфускацией xhttp)
Конфигурация для входной ноды, принимающей трафик от CDN (например, TimeWeb CDN / Selectel). Настроена обфускация мусорных пакетов (`xPadding`), чтобы скрыть структуру данных прокси от систем анализа CDN.

```json
{
  "log": {
    "loglevel": "warning"
  },
  "inbounds": [
    {
      "tag": "in-cdn-xhttp",
      "port": 8003,
      "listen": "127.0.0.1",
      "protocol": "vless",
      "settings": {
        "clients": [
          {
            "id": "ВАШ_UUID_ПОЛЬЗОВАТЕЛЯ"
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
          "xPaddingKey": "some_random_key_here",
          "xPaddingHeader": "X-Cache",
          "xPaddingMethod": "tokenish",
          "xPaddingPlacement": "queryInHeader"
        }
      }
    }
  ],
  "outbounds": [
    {
      "tag": "to-exit",
      "protocol": "vless",
      "settings": {
        "vnext": [
          {
            "address": "IP_ЗАРУБЕЖНОЙ_НОДЫ",
            "port": 443,
            "users": [
              {
                "id": "ВАШ_UUID_ПОЛЬЗОВАТЕЛЯ",
                "encryption": "none",
                "flow": "xtls-rprx-vision"
              }
            ]
          }
        ]
      },
      "streamSettings": {
        "network": "tcp",
        "security": "tls",
        "tlsSettings": {
          "serverName": "your-exit-domain.com",
          "alpn": ["h2", "http/1.1"]
        }
      }
    },
    {
      "tag": "DIRECT",
      "protocol": "freedom"
    }
  ],
  "routing": {
    "domainStrategy": "AsIs",
    "rules": [
      {
        "type": "field",
        "domain": [
          "domain:gstatic.com",
          "domain:www.gstatic.com",
          "domain:yandex.ru"
        ],
        "outboundTag": "DIRECT"
      }
    ]
  }
}
```

---

## ⚠️ Особенности и ограничения обхода БС

1.  **Эффект «Холодного старта»:**
    При использовании CDN первые секунды после подключения трафик может идти медленно или обрываться (идет инициализация и прогрев кэша CDN). Спустя 10-20 секунд соединение стабилизируется.
2.  **Заглушка (Decoy) на транзитном сервере:**
    Если вы используете транзитный VPS в РФ, обязательно настройте веб-сервер (Nginx / Caddy) на порту 80/443, который будет отдавать реальный легитимный сайт (заглушку) при обычном обращении, чтобы хостинг-провайдер или ТСПУ не заблокировали сервер за "несанкционированную прокси-активность".
3.  **Совместимость версий ядер:**
    Использование `xhttp` требует обязательного обновления ядра Xray-core как на стороне сервера, так и на стороне клиента. Старые версии клиентов (например, happ со старыми ядрами) не умеют работать с xhttp и будут выдавать ошибки. Рекомендуется использовать клиенты **Incy** или последние версии **NekoBox** / **v2rayN**.
