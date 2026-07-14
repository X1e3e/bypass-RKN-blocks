#!/bin/bash

# Запуск SpoofDPI на macOS с оптимальными параметрами для обхода ТСПУ (YouTube / Discord)

# Проверка, установлен ли spoofdpi
if ! command -v spoofdpi &> /dev/null
then
    echo "SpoofDPI не найден. Устанавливаем через Homebrew..."
    brew install xvzc/tap/spoofdpi
fi

echo "=== Запуск SpoofDPI с оптимизацией под YouTube и Discord ==="
echo "Используются параметры:"
echo "  - Дополнительный DoH DNS (--enable-doh)"
echo "  - Уменьшенный размер TCP-окна для обхода детекта (--window-size 30)"
echo "  - Применение только к YouTube, Google Video и Discord (--pattern)"

# Запуск spoofdpi с флагами
# --window-size 30 делает разбиение пакетов более частым, что мешает ТСПУ определять SNI
# --enable-doh предотвращает перехват DNS запросов провайдером
spoofdpi --enable-doh --window-size 30 --pattern "googlevideo.com|youtube.com|ytimg.com|ggpht.com|discord.com|discordapp.com|discord.gg"
