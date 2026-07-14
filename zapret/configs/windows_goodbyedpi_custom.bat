@echo off
:: Запуск GoodbyeDPI от имени Администратора
NET FILE 1>NUL 2>NUL
if '%errorlevel%' == '0' ( goto d_admin ) else ( goto get_admin )

:get_admin
    echo Нам нужны права Администратора...
    powershell -Command "Start-Process -FilePath '%0' -Verb RunAs"
    exit /b

:d_admin
    cd /d "%~dp0"
    echo Запуск GoodbyeDPI с оптимальными параметрами для YouTube и Discord...
    
    :: Проверка наличия исполняемого файла
    if not exist "goodbyedpi.exe" (
        if exist "x86_64\goodbyedpi.exe" (
            cd x86_64
        ) else (
            echo Ошибка: goodbyedpi.exe не найден! Пожалуйста, поместите этот скрипт в корневую папку GoodbyeDPI.
            pause
            exit /b
        )
    )

    :: Оптимальные параметры для ТСПУ (актуально на 2026 год):
    :: -e 1 (фрагментация SNI)
    :: -q (без повторов)
    :: --fake-gen 2 (генерация фейк-пакетов)
    :: --fake-resend 2 (повтор фейка)
    :: --split-pos 3 (деление TCP по позиции 3)
    :: --desync-ttl 3 (TTL десинхронизации)
    :: --native-frag (нативная фрагментация)
    :: --blacklist ..\russia-blacklist.txt (черный список сайтов)
    :: --blacklist ..\russia-youtube.txt (список доменов Youtube/Discord)
    
    goodbyedpi.exe -e 1 -q --fake-gen 2 --fake-resend 2 --split-pos 3 --desync-ttl 3 --native-frag --blacklist ..\russia-blacklist.txt --blacklist ..\russia-youtube.txt
    
    pause
