# Бізнес логіка для systemd

import std/strformat
import std/os
import std/strutils
import std/osproc

const SYSTEMD_DIR = "/etc/systemd/system"

proc create_systemd*(name, user, working_dir, exec_start: string, restart_sec, is_max_memmory: int32) =
    let memory_max =
        if is_max_memmory > 0: fmt"MemoryMax={is_max_memmory}"
        else: ""

    let config = fmt"""
[Unit]
Description=A customer service {name}
After=network.target
StartLimitIntervalSec=60
StartLimitBurst=5
OnFailure=failure-reporter@%n.service

[Service]
Type=simple
User={user}
WorkingDirectory={working_dir}
ExecStart={exec_start}
Restart=on-failure
RestartSec={restart_sec}
{memory_max}

[Install]
WantedBy=multi-user.target
"""

    writeFile(fmt"{SYSTEMD_DIR}/{name}.service", config)



proc read_systemd*(name: string, param = "all"): string = 
    if param == "all":
        return readFile(fmt"{SYSTEMD_DIR}/{name}.service")
    else:
        for line in lines(fmt"{SYSTEMD_DIR}/{name}.service"):
            if line.contains(param):
                return line.split('=', maxsplit = 1)[1]



proc update_systemd*(name, param, new_value: string) =
    let filePath = fmt"{SYSTEMD_DIR}/{name}.service"
    var linesSeq = readFile(filePath).splitLines()

    for i in 0 ..< linesSeq.len:
        if linesSeq[i].contains(param):
            linesSeq[i] = fmt"{param}={new_value}"

    writeFile(filePath, linesSeq.join("\n") & "\n")



proc delete_systemd*(name: string) = 
    removeFile(fmt"{SYSTEMD_DIR}/{name}.service")



#* ---------



proc reload_systemd*(): int =
    let exitCode = execCmd(fmt"sudo systemctl daemon-reload")
    return exitCode



proc reenable_systemd*(name: string): int =
    let exitCode = execCmd(fmt"sudo systemctl reenable --now {name}.service")
    return exitCode



proc restart_systemd*(name: string): int =
    let exitCode = execCmd(fmt"sudo systemctl restart --now {name}.service")
    return exitCode



proc disable_systemd*(name: string): int =
    let exitCode = execCmd(fmt"sudo systemctl disable --now {name}.service")
    return exitCode


proc enable_systemd*(name:string): int =
    let exitCode = execCmd(fmt"sudo systemctl enable --now {name}.service")
    return exitCode



proc view_logs_systemd*(name: string, amount: int32): string =
    let (output, _) = execCmdEx(fmt"journalctl -u {name}.service -n {amount} -f")
    return output.strip()



proc view_status_systemd*(name: string): string = 
    let (output, _) = execCmdEx(fmt"sudo systemctl show -p ActiveState --value {name}.service")
    return output.strip()

