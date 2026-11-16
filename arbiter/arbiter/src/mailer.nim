# Бізнес логіка для відправки повідомлень користувачу

import std/strformat
import std/os
import std/json
import std/httpclient

import conf


let HOME = getEnv("HOME")
const QUEUE_FILE = "messages.json"
const PROJECT_NAME = "arbiter"

let queue_file_path = fmt"{HOME}/.config/{PROJECT_NAME}/{QUEUE_FILE}"



proc loadQueue(path = queue_file_path): JsonNode =
    if not fileExists(path):
        return %* {"messages": []}
    try:
        result = parseFile(path)
        if not result.hasKey("messages") or result["messages"].kind != JArray:
            result = %* {"messages": []}
    except CatchableError:
        result = %* {"messages": []}

proc saveQueue(q: JsonNode, path = queue_file_path) =
    createDir(parentDir(path))
    let tmp = path & ".tmp"
    writeFile(tmp, q.pretty())
    moveFile(tmp, path)

proc hasMessages(path = queue_file_path): bool =
    loadQueue(path)["messages"].len > 0

iterator pendingMessages(path = queue_file_path): JsonNode =
    let q = loadQueue(path)
    for msg in q["messages"]:
        yield msg

proc enqueue(msg: JsonNode, path = queue_file_path) =
    let q = loadQueue(path)
    q["messages"].add(msg)
    saveQueue(q, path)

proc removeMessage(msg: JsonNode, path = queue_file_path): bool =
    let q = loadQueue(path)
    let arr = q["messages"]
    for i in 0 ..< arr.len:
        if arr[i] == msg:
            arr.elems.delete(i)
            saveQueue(q, path)
            return true
    false



#* ---



proc send_app(msg: JsonNode): bool =
    ## Має повертати true, лише якщо повідомлення реально доставлено.
    false



proc sendTelegram(msg: JsonNode, token: string = read_conf("TELEGRAM_BOT_TOKEN")): bool =
    if token.len == 0 or msg.isNil or msg.kind != JObject:
        return false

    let client = newHttpClient(timeout = 10_000)
    defer: client.close()
    client.headers = newHttpHeaders({"Content-Type": "application/json"})

    try:
        let resp = client.post(
            "https://api.telegram.org/bot" & token & "/sendMessage",
            body = $msg
        )
        if resp.code != Http200:
            return false
        let data = parseJson(resp.body)
        return data.getOrDefault("ok").getBool(false)
    except CatchableError:
        return false



proc deliver(msg: JsonNode): bool =
    case read_conf("msg_type")
    of "app":
        send_app(msg)
    of "telegram":
        let a = send_app(msg)
        let t = send_telegram(msg)
        a and t
    else:
        false



proc send_msg*(category, message, module: string, log = "") =
    let msg = %* {
        "category": category,
        "message": message,
        "module": module,
        "log": log
    }

    if not deliver(msg):
        enqueue(msg)
    echo category, "\n", message, module, log



when isMainModule:
    if not hasMessages():
        quit(0)

    var sent, failed = 0
    for msg in pendingMessages():
        if deliver(msg) and removeMessage(msg):
            inc sent
        else:
            inc failed

    quit(if failed > 0: 1 else: 0)