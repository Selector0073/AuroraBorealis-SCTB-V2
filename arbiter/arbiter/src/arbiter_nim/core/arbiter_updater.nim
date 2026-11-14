# Arbiter updater

import std/httpclient
import std/json
import std/strutils
import std/strformat
import std/os
import std/uri
import std/osproc
import std/sequtils

import conf
import mailer

const
    USERNAME = "Selector0073"
    REPO = "AuroraBorealis-SCTB-V2"
    DOWNLOAD_FILE = "arbiter.tar.gz"
    OUTPUT_FILE = "latest.tar.gz"



proc download_latest*(): string =
    let url = &"https://github.com/{USERNAME}/{REPO}/releases/latest/download/{DOWNLOAD_FILE}"
    let destPath = "latest" / DOWNLOAD_FILE
    let tmpPath = destPath & ".part"

    createDir("latest")

    let client = newHttpClient(maxRedirects = 10, timeout = 60000)
    defer: client.close()

    try:
        client.downloadFile(url, tmpPath)
        moveFile(tmpPath, destPath)
    except HttpRequestError as e:
        if fileExists(tmpPath): removeFile(tmpPath)
        send_msg("error", "Cant download latest version from github", "arbiter_updater.nim/download_latest", e.msg)
        raise newException(IOError, &"Cant download {url}: {e.msg}")
    except CatchableError as e:
        if fileExists(tmpPath): removeFile(tmpPath)
        send_msg("error", "Unexpected error during download", "arbiter_updater.nim/download_latest", e.msg)
        raise

    result = destPath



proc get_latest_version*(): string =
    let client = newHttpClient()
    defer: client.close()
    client.headers = newHttpHeaders({
        "User-Agent": "nim-mindustry-version-check",
        "Accept": "application/vnd.github+json"
    })

    let body = client.getContent(
        fmt"https://api.github.com/repos/{USERNAME}/{REPO}/releases/latest")
    result = parseJson(body)["tag_name"].getStr()



proc is_need_update*(): bool = 
    if get_latest_version() == read_conf("version"):
        return false
    else:
        return true























proc sh(workDir: string, args: varargs[string]): tuple[output: string, exitCode: int] =
    execCmdEx(quoteShellCommand(@args), workingDir = workDir)

proc fail(msg: string) {.noreturn.} =
    send_msg("error", msg, "arbiter_updater.nim/unpack_update")
    raise newException(IOError, msg)

proc isSafeEntry(entry: string): bool =
    let e = entry.strip(chars = {'\r', '\n'})
    if e.len == 0 or e.startsWith("/") or e.isAbsolute: return false
    for part in e.split({'/', '\\'}):
        if part == "..": return false
    true

proc atomicCopy(src, dst: string) =
    ## Копіюємо в тимчасовий файл і робимо rename. Це працює навіть
    ## якщо dst - запущений виконуваний файл (без "Text file busy").
    let tmp = dst & ".new"
    copyFileWithPermissions(src, tmp)
    moveFile(tmp, dst)

proc runTests(latest: string) =
    if findExe("nim") == "":
        fail("nim not found in PATH")

    let nimbleFiles = toSeq(walkFiles(latest / "*.nimble"))
    if nimbleFiles.len > 0 and findExe("nimble") != "":
        let (output, code) = sh(latest, "nimble", "test", "-y")
        if code != 0: fail("Tests (nimble test) failed:\n" & output)
        return

    let testFiles = toSeq(walkFiles(latest / "tests" / "t*.nim"))
    if testFiles.len == 0:
        fail("Tests not found (not .nimble, not tests/t*.nim)")

    let tmpOut = getTempDir() / "unpack_update_tests"
    removeDir(tmpOut)
    createDir(tmpOut)
    try:
        for f in testFiles:
            let (output, code) = sh(latest, "nim", "c", "-r", "--hints:off",
                                                            "--outdir:" & tmpOut,
                                                            "--nimcache:" & (tmpOut / "cache"), f)
            if code != 0:
                fail("Test failed: " & f & "\n" & output)
    finally:
        removeDir(tmpOut)

proc unpack_update*() =
    let
        root = getCurrentDir()
        latest = root / "latest"
        archive = latest / OUTPUT_FILE
        backup = root / "update_backup"

    if not fileExists(archive):
        fail("Archive not found: " & archive)
    if findExe("tar") == "":
        fail("The tar utility was not found")

    let (names, c1) = sh(latest, "tar", "-tzf", archive)
    if c1 != 0: fail("Failed to read the archive:\n" & names)
    for line in names.splitLines():
        if line.len > 0 and not isSafeEntry(line):
            fail("A dangerous path in the archive: " & line)

    let (verbose, c2) = sh(latest, "tar", "-tvzf", archive)
    if c2 != 0: fail("Failed to read the archive:\n" & verbose)
    for line in verbose.splitLines():
        if line.len > 0 and line[0] in {'l', 'h'}:
            fail("The archive contains symbolic/hard links: " & line)

    # 2. Розпакування в latest/
    let (xout, c3) = sh(latest, "tar", "-xzf", archive, "--no-same-owner", "-C", latest)
    if c3 != 0: fail("Unpacking error:\n" & xout)

    # 3. Знімок списку файлів ДО тестів (щоб не підхопити артефакти збірки)
    var files: seq[string]
    for rel in walkDirRec(latest, yieldFilter = {pcFile}, relative = true):
        if rel != OUTPUT_FILE:
            files.add rel

    # 4. Тести
    runTests(latest)

    # 5. Заміна файлів з бекапом і відкатом при помилці
    removeDir(backup)
    createDir(backup)

    var done: seq[tuple[rel: string, hadOld: bool]]
    try:
        for rel in files:
            let
                src = latest / rel
                dst = root / rel
            createDir(parentDir(dst))
            let hadOld = fileExists(dst)
            if hadOld:
                createDir(parentDir(backup / rel))
                copyFileWithPermissions(dst, backup / rel)
            atomicCopy(src, dst)
            done.add (rel, hadOld)
    except CatchableError as e:
        # відкат
        for d in done:
            try:
                if d.hadOld: atomicCopy(backup / d.rel, root / d.rel)
                else: removeFile(root / d.rel)
            except CatchableError: discard
        fail("Update error, backup performed: " & e.msg)

    removeDir(backup)