#!/usr/bin/env bash

# Суворий режим виконання
set -euo pipefail

# Перевірка на виконання з правами суперкористувача (root)
if [[ $EUID -ne 0 ]]; then
    echo "[Критично] Цей скрипт вимагає прав суперкористувача (root)." >&2
    exit 1
fi

# Отримання вхідних даних
read -rp "Введіть ім'я нового користувача: " USERNAME

# Валідація імені користувача за допомогою стандартних регулярних виразів Linux
if [[ ! "$USERNAME" =~ ^[a-z_][a-z0-9_-]*$ ]]; then
    echo "[Помилка] Некоректне ім'я користувача. Дозволені лише малі латинські літери, цифри, дефіси та підкреслення." >&2
    exit 1
fi

# Перевірка існування користувача в системі
if id "$USERNAME" &>/dev/null; then
    echo "[Помилка] Користувач '$USERNAME' вже існує." >&2
    exit 1
fi

read -rsp "Введіть пароль для користувача: " PASSWORD
echo
read -rsp "Підтвердіть пароль: " PASSWORD_CONFIRM
echo

if [[ "$PASSWORD" != "$PASSWORD_CONFIRM" ]]; then
    echo "[Помилка] Паролі не збігаються." >&2
    exit 1
fi

# Визначення параметрів дистрибутиву через /etc/os-release
if [[ -f /etc/os-release ]]; then
    . /etc/os-release
    OS_ID="${ID:-}"
    # Деякі похідні дистрибутиви мають ID_LIKE (наприклад, linuxmint має id_like=ubuntu debian)
    OS_ID_LIKE="${ID_LIKE:-}"
else
    echo "[Помилка] Файл /etc/os-release відсутній. Неможливо ідентифікувати дистрибутив." >&2
    exit 1
fi

# Створення користувача:
# -m : створити домашню директорію (/home/username)
# -s : встановити стандартну оболонку (bash)
useradd -m -s /bin/bash "$USERNAME"
echo "[Інфо] Домашню директорію для '$USERNAME' створено."

# Безпечне встановлення пароля через стандартний ввід chpasswd
echo "$USERNAME:$PASSWORD" | chpasswd
echo "[Інфо] Пароль успішно оновлено."

# Призначення прав адміністратора (sudo / wheel) залежно від сімейства ОС
if [[ "$OS_ID" =~ ^(debian|ubuntu|linuxmint|pop|kali|raspbian)$ ]] || [[ "$OS_ID_LIKE" =~ (debian|ubuntu) ]]; then
    usermod -aG sudo "$USERNAME"
    ADMIN_GROUP="sudo"
elif [[ "$OS_ID" =~ ^(fedora|rhel|centos|rocky|almalinux|fedora-asahi-remix)$ ]] || [[ "$OS_ID_LIKE" =~ (rhel|fedora) ]]; then
    usermod -aG wheel "$USERNAME"
    ADMIN_GROUP="wheel"
else
    echo "[Попередження] Невідомий дистрибутив ($OS_ID). Групу адміністраторів не призначено автоматично."
    ADMIN_GROUP=""
fi

if [[ -n "$ADMIN_GROUP" ]]; then
    echo "[Інфо] Користувача '$USERNAME' успішно додано до адміністративної групи '$ADMIN_GROUP'."
fi

echo "[Успіх] Обліковий запис '$USERNAME' повністю налаштований."