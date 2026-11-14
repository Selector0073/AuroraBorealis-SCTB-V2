# Бізнес логіка для nginx

import std/strformat
import std/os
import std/strutils
import std/osproc

const
    SYSTEMD_DIR = "/etc/nginx/sites-available"
    SITES_AVAILABLE = "/etc/nginx/sites-available"
    SITES_ENABLED   = "/etc/nginx/sites-enabled"
    LOG_DIR         = "/var/log/nginx"


proc create_nginx*(domain, ssl: string, port: int32,
                    client_max_body_mb: int32 = 0,
                    connect_timeout: int32 = 0, send_timeout: int32 = 0, read_timeout: int32 = 0,
                    keepalive_timeout: int32 = 0,
                    hsts_max_age: int32 = 0,
                    gzip_min_length: int32 = 0,
                    proxy_buffering_off: int32 = 0,
                    access_log: string = "", error_log: string = "", auth_basic_file: string = "") =

    let body_size =
        if client_max_body_mb > 0: fmt"    client_max_body_size {client_max_body_mb}m;"
        else: ""

    let keepalive =
        if keepalive_timeout > 0: fmt"    keepalive_timeout {keepalive_timeout}s;"
        else: ""

    let hsts =
        if hsts_max_age > 0:
            fmt"""    add_header Strict-Transport-Security "max-age={hsts_max_age}; includeSubDomains" always;"""
        else: ""

    let gzip =
        if gzip_min_length > 0:
            fmt"    gzip on;{'\n'}    gzip_min_length {gzip_min_length};{'\n'}    gzip_proxied any;"
        else: ""

    let access_log_line =
        if access_log.len > 0: fmt"    access_log {access_log};"
        else: ""

    let error_log_line =
        if error_log.len > 0: fmt"    error_log {error_log};"
        else: ""

    let proxy_connect =
        if connect_timeout > 0: fmt"        proxy_connect_timeout {connect_timeout}s;"
        else: ""

    let proxy_send =
        if send_timeout > 0: fmt"        proxy_send_timeout {send_timeout}s;"
        else: ""

    let proxy_read =
        if read_timeout > 0: fmt"        proxy_read_timeout {read_timeout}s;"
        else: ""

    let buffering =
        if proxy_buffering_off > 0: "        proxy_buffering off;"
        else: ""

    let auth_basic =
        if auth_basic_file.len > 0:
            fmt"        auth_basic ""Restricted"";{'\n'}        auth_basic_user_file {auth_basic_file};"
        else: ""

    let config = fmt"""
server {{
    listen 80;
    listen [::]:80;
    server_name {domain};

    return 301 https://$host$request_uri;
}}

server {{
    listen 443 ssl;
    listen [::]:443 ssl;
    http2 on;
    
    server_name {domain};

    ssl_certificate /etc/letsencrypt/live/{ssl}/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/{ssl}/privkey.pem;

    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_prefer_server_ciphers on;
    ssl_ciphers HIGH:!aNULL:!MD5;

{body_size}
{keepalive}
{hsts}
{gzip}
{access_log_line}
{error_log_line}

    location / {{
        proxy_pass http://127.0.0.1:{port};
        proxy_http_version 1.1;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
{proxy_connect}
{proxy_send}
{proxy_read}
{buffering}
{auth_basic}
    }}
}}
"""

    writeFile(fmt"{SYSTEMD_DIR}/{domain}", config)



proc read_nginx*(domain: string, param = "all"): string = 
    if param == "all":
        return readFile(fmt"{SYSTEMD_DIR}/{domain}")
    else:
        for line in lines(fmt"{SYSTEMD_DIR}/{domain}"):
            if line.contains(param):
                return line.split('=', maxsplit = 1)[1]



proc update_nginx*(domain, old_value, new_value: string) =
    let filePath = fmt"{SYSTEMD_DIR}/{domain}"
    var linesSeq = readFile(filePath).splitLines()

    for i in 0 ..< linesSeq.len:
        if linesSeq[i].contains(old_value):
            linesSeq[i] = new_value

    writeFile(filePath, linesSeq.join("\n") & "\n")



proc delete_nginx*(domain: string) = 
    removeFile(fmt"{SYSTEMD_DIR}/{domain}")



#* ---------



proc test_nginx*(): tuple[output: string, code: int] =
    let (output, code) = execCmdEx("sudo nginx -t")
    return (output.strip(), code)



proc reload_nginx*(): int =
    let (_, testCode) = test_nginx()
    if testCode != 0:
        return testCode
    return execCmd("sudo systemctl reload nginx.service")



proc restart_nginx*(): int =
    ## Повний рестарт (розриває активні з'єднання), теж з перевіркою
    let (_, testCode) = test_nginx()
    if testCode != 0:
        return testCode
    return execCmd("sudo systemctl restart nginx.service")



proc start_nginx*(): int =
    return execCmd("sudo systemctl start nginx.service")



proc stop_nginx*(): int =
    return execCmd("sudo systemctl stop nginx.service")



proc enable_site*(domain: string): int =
    let src = fmt"{SITES_AVAILABLE}/{domain}"
    let dst = fmt"{SITES_ENABLED}/{domain}"

    if not fileExists(src):
        return 1
    if not symlinkExists(dst):
        createSymlink(src, dst)

    let code = reload_nginx()
    if code != 0:
        removeFile(dst)
    return code



proc disable_site*(domain: string): int =
    let dst = fmt"{SITES_ENABLED}/{domain}"
    if symlinkExists(dst):
        removeFile(dst)
    return reload_nginx()



proc is_site_enabled*(domain: string): bool =
    return symlinkExists(fmt"{SITES_ENABLED}/{domain}")



proc view_logs*(kind: string = "error", amount: int32 = 100): string =
    let file =
        if kind == "access": fmt"{LOG_DIR}/access.log"
        else: fmt"{LOG_DIR}/error.log"
    let (output, _) = execCmdEx(fmt"sudo tail -n {amount} {quoteShell(file)}")
    return output.strip()



proc view_status*(): string =
    let (state, _) = execCmdEx("systemctl is-active nginx.service")
    let (testOut, testCode) = test_nginx()
    let configState = if testCode == 0: "config OK" else: "config ERROR"
    return fmt"service: {state.strip()}{'\n'}{configState}{'\n'}{testOut}"

