#!/bin/bash

# Скрипт автоматизированной настройки zapret на Linux (Debian/Ubuntu/CentOS)
# Проверяет зависимости, скачивает zapret и настраивает оптимальные параметры для обхода ТСПУ

set -e

# Проверка на права root
if [ "$EUID" -ne 0 ]; then
    echo "Пожалуйста, запустите скрипт с правами root (sudo)."
    exit 1
fi

echo "=== Подготовка к установке zapret на Linux ==="

# Определение пакетного менеджера
if command -v apt-get &>/dev/null; then
    echo "Обнаружен менеджер пакетов APT. Установка зависимостей..."
    apt-get update
    apt-get install -y git curl nftables ipset iptables coreutils dnsutils
elif command -v dnf &>/dev/null; then
    echo "Обнаружен менеджер пакетов DNF. Установка зависимостей..."
    dnf install -y git curl nftables ipset iptables coreutils bind-utils
elif command -v yum &>/dev/null; then
    echo "Обнаружен менеджер пакетов YUM. Установка зависимостей..."
    yum install -y git curl nftables ipset iptables coreutils bind-utils
else
    echo "Не удалось определить пакетный менеджер. Пожалуйста, установите git, curl, nftables и ipset вручную."
fi

# Клонирование репозитория zapret во временную директорию
ZAPRET_DIR="/opt/zapret"
if [ -d "$ZAPRET_DIR" ]; then
    echo "Папка $ZAPRET_DIR уже существует. Обновляем репозиторий..."
    cd "$ZAPRET_DIR"
    git pull
else
    echo "Клонирование репозитория zapret в $ZAPRET_DIR..."
    git clone --depth=1 https://github.com/bol-van/zapret.git "$ZAPRET_DIR"
fi

# Переход в папку установки
cd "$ZAPRET_DIR"

echo "=== Запуск установщика install_easy.sh ==="
echo "Вы будете перенаправлены в интерактивный скрипт настройки bol-van."
echo "Рекомендуемые ответы для пользователей из РФ:"
echo "1. Выберите тип брандмауэра (nftables рекомендуется для современных систем)."
echo "2. Выберите тип фильтрации (по спискам доменов / ipset)."
echo "3. В конфигурационном файле (/etc/zapret/config) пропишите опции desync:"
echo "   NFQWS_OPT_DESYNC=\"--desync-mode=fake,disorder2 --desync-ttl=3 --desync-fooling=md5sig,badsum\""
echo ""
read -p "Нажмите Enter для запуска установщика..."

./install_easy.sh
