# Бізнес логіка для конфігурації

import std/strformat
import std/os
import std/strutils

let HOME = getEnv("HOME")
const PROJECT_NAME = "arbiter"



proc add_conf*(param, value: string) =
    let f = open(fmt"{HOME}/.config/{PROJECT_NAME}/config.toml", fmAppend)
    defer: f.close()
    f.writeLine(fmt"{param}={value}")



proc read_conf*(param = "all"): string =
    if param == "all":
        return readFile(fmt"{HOME}/.config/{PROJECT_NAME}/config.toml")
    else:
        for line in lines(fmt"{HOME}/.config/{PROJECT_NAME}/config.toml"):
            if line.contains(param):
                return line.split('=', maxsplit = 1)[1]



proc update_conf*(param, new_value: string) =
    let filePath = fmt"{HOME}/.config/{PROJECT_NAME}/config.toml"
    var linesSeq = readFile(filePath).splitLines()

    for i in 0 ..< linesSeq.len:
        if linesSeq[i].startsWith(fmt"{param}="):
            if new_value == "":
                linesSeq[i] = ""
            else:
                linesSeq[i] = fmt"{param}={new_value}"

    writeFile(filePath, linesSeq.join("\n") & "\n")