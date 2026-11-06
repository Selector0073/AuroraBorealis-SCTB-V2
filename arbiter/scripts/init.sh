#!/bin/bash

PROJECT_NAME="server_app"
DIR="$(dirname "$0")"
source "$DIR/install_software.sh"
source "$DIR/setup.sh"
[ "$(id -u)" -eq 0 ] && SUDO="" || SUDO="sudo"



#* Check sudo
if [[ $EUID -ne 0 ]]; then
    echo "Run the script as root (e.g. via sudo)." >&2
    exit 1
fi



#* Check OS
HOST_ID_LIKE=$(. /etc/os-release && echo "${ID_LIKE:-$ID}")

if [[ "$HOST_ID_LIKE" != *debian* && "$HOST_ID_LIKE" != *fedora* ]]; then
    echo "Sorry, but your system is not supported."
    echo "You can only use systems based on Debian or Fedora."
    exit 1
fi


#* Create config
echo "[main]
project_name = ${PROJECT_NAME}
host_id_like= ${HOST_ID_LIKE}" > config.toml


#* Update system
os_setup "$HOST_ID_LIKE"



#* Check whiptail
if ! command -v whiptail &>/dev/null; then
    echo "'whiptail' is not installed, installing..." >&2
    case "$HOST_ID_LIKE" in
        *debian*) install_pkg "$HOST_ID_LIKE" whiptail ;;
        *fedora*) install_pkg "$HOST_ID_LIKE" newt ;;
    esac
fi



#* Choose setup options 
CHOICES=$(whiptail --title "Setup config" --checklist \
"Select components for installation (Space - select, Enter - confirm):" 20 70 8 \
"ssh" "Fail2ban + change ssh port 22 -> 2222" ON \
"security" "Automatic security updates" ON \
"nginx" "Nginx" OFF \
"firewall" "UFW firewall" ON \
"ssl" "Lets Encrypt sertificates" OFF \
"new-user" "Create new user" ON \
"failure-reporter" "Enable failure reporter service" ON 3>&1 1>&2 2>&3)

exit_status=$?
if [ $exit_status -ne 0 ]; then
    echo "Operation canceled by user."
    exit 0
fi
[ -z "$CHOICES" ] && { echo "No options chosen."; exit 0; }

declare -A OPTS=( [ssh]=False [security]=False [nginx]=False [firewall]=False [ssl]=False [new-user]=False [failure-reporter]=False)

for item in $CHOICES; do
    name="${item//\"/}"
    case "$name" in
        ssh) 
            setup_ssh "$HOST_ID_LIKE"
            OPTS[ssh]=True ;;
        security) 
            setup_security "$HOST_ID_LIKE"
            OPTS[security]=True ;;
        nginx) 
            setup_nginx "$HOST_ID_LIKE"
            OPTS[nginx]=True ;;
        firewall) 
            setup_firewall "$HOST_ID_LIKE"
            OPTS[firewall]=True ;;
        ssl) 
            setup_ssl "$HOST_ID_LIKE"
            OPTS[ssl]=True ;;
        new-user)
            setup_user 
            OPTS[new-user]=True ;;
        failure-reporter)
            failure-reporter
            OPTS[failure-reporter]=True ;;
    esac
done

for key in "${!OPTS[@]}"; do
    echo "${key}=${OPTS[$key]}" >> config.toml
done



#* Moving config.toml to .config/
CONFIG_FOLDER_PATH="${HOME}/.config/${PROJECT_NAME}/"
mkdir -p "${CONFIG_FOLDER_PATH}"
mv config.toml "${CONFIG_FOLDER_PATH}"
