#!/bin/bash

set -euo pipefail

# $1 - email (required)
register_ssl() {
    local email="${1:?Email required: register_ssl <email>}"

    sudo certbot register --agree-tos -m "$email" --no-eff-email
    sudo mkdir -p /etc/letsencrypt
    sudo tee /etc/letsencrypt/cli.ini > /dev/null <<EOF
authenticator = nginx
installer = nginx
agree-tos = true
email = ${email}
no-eff-email = true
EOF
}

# $1 - primary domain (required), $2... - additional domains (optional)
test_create_ssl() {
    local domain="${1:?Domain required: test_create_ssl <domain> [alias_domain...]}"
    shift
    local args=(-d "$domain")
    local alias
    for alias in "$@"; do
        args+=(-d "$alias")
    done

    sudo certbot --nginx "${args[@]}" --staging
}

# $1 - primary domain (required), $2... - additional domains, eg. www.example.com (optional)
create_ssl() {
    local domain="${1:?Domain required: create_ssl <domain> [alias_domain...]}"
    shift
    local args=(-d "$domain")
    local alias
    for alias in "$@"; do
        args+=(-d "$alias")
    done

    sudo certbot --nginx "${args[@]}"
    echo "0 3 * * * root certbot renew --quiet --deploy-hook 'systemctl reload nginx'" \
        | sudo tee /etc/cron.d/certbot-renew > /dev/null
}

# $1 - domain (optional, without it shows all certificates)
read_ssl() {
    local domain="${1:-}"

    if [[ -z "$domain" ]]; then
        sudo certbot certificates
        return
    fi

    sudo certbot certificates --cert-name "$domain"
    local cert="/etc/letsencrypt/live/${domain}/cert.pem"
    if sudo test -f "$cert"; then
        echo "Valid until: $(sudo openssl x509 -enddate -noout -in "$cert" | cut -d= -f2)"
    fi
}

# $1 - domain (optional, empty string shows all certificates)
# $2 - "force" to force renewal (optional)
update_ssl() {
    local domain="${1:-}"
    local force="${2:-}"
    local args=(--deploy-hook 'systemctl reload nginx')

    [[ -n "$domain" ]] && args+=(--cert-name "$domain")
    [[ "$force" == "force" ]] && args+=(--force-renewal)

    sudo certbot renew "${args[@]}"
}

# $1 - domain / certificate name (required)
delete_ssl() {
    local domain="${1:?Domain required: delete_ssl <domain>}"

    local ts backup_dir f
    ts=$(date +%Y%m%d%H%M%S)
    backup_dir="/var/backups/nginx-ssl-${ts}"
    local files=()
    mapfile -t files < <(sudo grep -rl "/etc/letsencrypt/live/${domain}/" /etc/nginx 2>/dev/null || true)

    if [[ ${#files[@]} -gt 0 ]]; then
        sudo mkdir -p "$backup_dir"
        for f in "${files[@]}"; do
            sudo cp -a "$f" "${backup_dir}/${f//\//_}"
            sudo sed -i '/# managed by Certbot/d' "$f"
        done

        if ! sudo nginx -t; then
            echo "nginx -t failed, rolling back config from ${backup_dir}" >&2
            for f in "${files[@]}"; do
                sudo cp -a "${backup_dir}/${f//\//_}" "$f"
            done
            return 1
        fi
    fi

    sudo certbot delete --cert-name "$domain" --non-interactive
    sudo systemctl reload nginx
    echo "Certificate '$domain' deleted, ssl directives removed, nginx reloaded."
    [[ ${#files[@]} -gt 0 ]] && echo "Config backup: ${backup_dir}"
    return 0
}

