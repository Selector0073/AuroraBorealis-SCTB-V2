#!/bin/bash

setup_ssh() {
    local os="$1" svc=sshd
    [[ "$os" == *debian* ]] && svc=ssh

    command -v fail2ban-client &>/dev/null || install_pkg "$os" fail2ban

    mkdir -p /etc/ssh/sshd_config.d
    echo "Port 2222" > /etc/ssh/sshd_config.d/10-port.conf

    if command -v semanage &>/dev/null; then
        semanage port -a -t ssh_port_t -p tcp 2222 2>/dev/null || true
    fi

    if systemctl is-enabled ssh.socket &>/dev/null; then
        systemctl disable --now ssh.socket
        systemctl enable ssh
    fi
    systemctl restart "$svc"

    cat > /etc/fail2ban/jail.local << 'EOF'
[sshd]
enabled = true
port = 2222
backend = systemd
maxretry = 3
bantime = 1h
findtime = 10m
EOF
    systemctl enable --now fail2ban
    systemctl restart fail2ban
}



setup_security() {
    local os="$1"
    if [[ "$os" == *debian* ]]; then
        install_pkg "$os" unattended-upgrades
        cat > /etc/apt/apt.conf.d/20auto-upgrades << 'EOF'
APT::Periodic::Update-Package-Lists "1";
APT::Periodic::Unattended-Upgrade "1";
APT::Periodic::AutocleanInterval "7";
EOF
    elif [[ "$os" == *fedora* ]]; then
        install_pkg "$os" dnf-automatic
        sed -i 's/^apply_updates = .*/apply_updates = yes/'  /etc/dnf/automatic.conf
        sed -i 's/^upgrade_type = .*/upgrade_type = security/' /etc/dnf/automatic.conf
        systemctl enable --now dnf-automatic.timer
    fi
}



setup_nginx() {
    local os="$1"
    command -v nginx &>/dev/null || install_pkg "$os" nginx
    systemctl enable --now nginx
}



setup_firewall() {
    local os="$1"
    command -v ufw &>/dev/null || install_pkg "$os" ufw

    local ssh_port
    ssh_port=$(sshd -T 2>/dev/null | awk '/^port /{print $2; exit}')
    ssh_port=${ssh_port:-22}

    ufw default deny incoming
    ufw default allow outgoing
    ufw allow "${ssh_port}/tcp"
    ufw allow 80/tcp
    ufw allow 443/tcp
    ufw --force enable
    ufw status verbose
}



setup_ssl() {
    local os="$1"
    command -v python3 &>/dev/null || install_pkg "$os" python3
    command -v certbot &>/dev/null || pip install certbot --break-system-packages
    command -v certbot-nginx &>/dev/null || pip install certbot-nginx --break-system-packages
}



setup_user() {
    read -rp "Username: " username
    read -rsp "Password: " password
    echo

    if id "$username" &>/dev/null; then
        echo "Error: user '$username' is already existing" >&2
        return 1
    fi

    useradd -m -s /bin/bash "$username" || return 1
    echo "$username:$password" | chpasswd || return 1

    echo "User '$username' created"
}



failure-reporter() {
    local email
    local email_regex='^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$'

    while true; do
        read -rp "Email: " email
        echo 

        if [[ -z "${email}" ]]; then
            echo "Error: email cannot be empty." >&2
            continue
        fi

        if [[ ! "${email}" =~ ${email_regex} ]]; then
            echo "Error: email not valid." >&2
            continue
        fi

        break
    done

    echo "email=\"${email}\"" >> config.toml
                                                                                #! FINISH
    echo "" >> /etc/systemd/system/failure-reporter@.service
}
