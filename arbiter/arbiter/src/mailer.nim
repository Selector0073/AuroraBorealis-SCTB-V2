# Бізнес логіка для відправки повідомлень користувачу

import std/strformat
import std/os
# import std/httpclient     for telegram API
import std/times
import db_connector/db_sqlite
import std/options 
import std/strutils

# import conf       to check where to send messages


let HOME = getEnv("HOME")
const APP_NAME {.strdefine.} = "varden"
const QUEUE_FILE = "db.db"

let queue_file_path = fmt"{HOME}/.config/{APP_NAME}/{QUEUE_FILE}"

type
    Category = enum
        categInfo = "info"
        categWarning = "warning"
        categError = "error"

    Message = object
        id: int64
        category: Category
        message: string
        module: string
        log: string
        created_on: DateTime



const createTableSql = sql"""
    CREATE TABLE IF NOT EXISTS queue (
        id         INTEGER PRIMARY KEY AUTOINCREMENT,
        category   TEXT    NOT NULL CHECK (category IN ('info', 'warning', 'error')),
        message    TEXT    NOT NULL,
        module     TEXT    NOT NULL,
        log        TEXT    NOT NULL,
        created_on INTEGER NOT NULL
    );"""


proc open_db(): DbConn =
    result = open(queue_file_path, "", "", "")
    result.exec(createTableSql)


proc add_to_queue(msg: Message) =
    let db = open_db()
    defer: db.close()
    db.exec(sql"INSERT INTO queue (category, message, module, log, created_on) VALUES (?, ?, ?, ?, ?);",
            $msg.category, msg.message, msg.module, msg.log, $msg.created_on)


proc remove_from_queue(id: int64) =
    let db = open_db()
    defer: db.close()
    db.exec(sql"DELETE FROM queue WHERE id = ?;", $id)


proc parseMessage(row: Row): Message =
    result.id = parseBiggestInt(row[0])
    result.category = parseEnum[Category](row[1])
    result.message = row[2]
    result.module = row[3]
    result.log = row[4]
    result.created_on = fromUnix(parseBiggestInt(row[5])).utc()


proc get_queue_element(): Option[Message] =
    let db = open_db()
    defer: db.close()

    let rows = db.getAllRows(sql"""
        SELECT *
        FROM queue
        ORDER BY id ASC
        LIMIT 1;
        """)

    if rows.len == 0:
        return none(Message)

    return some(parseMessage(rows[0]))



#* ---



proc send_to_app(msg: Message): bool =
    try:
        # TODO: Відправка повідомлення в додаток
        return true
    except CatchableError:
        return false


proc flush_queue(): bool =
    while true:
        let item = get_queue_element()
        if item.isNone:
            return true
        let msg = item.get
        if not send_to_app(msg):
            return false
        remove_from_queue(msg.id)


proc send_msg*(category_input, message_input, module_input: string, log_input = "") =
    let msg = Message(
        category: parseEnum[Category](category_input),
        message: message_input,
        module: module_input,
        log: log_input,
        created_on: now().utc()
    )

    if flush_queue() and send_to_app(msg):
        return

    add_to_queue(msg)



#* ---



when isMainModule:
    discard flush_queue()

