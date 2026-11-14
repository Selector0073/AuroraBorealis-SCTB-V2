# Package

version       = "0.1.0"
author        = "AuroraBorealis"
description   = "arbiter nim part"
license       = "MIT"
srcDir        = "src"


# Dependencies

requires "nim >= 2.4.0"


task buildlib, "Build Nim arbiter static lib":
    let root = thisDir() & "/../.."
    mkDir root & "/release-arbiter"
    withDir thisDir():
        exec "nim c" &
            " --app:staticlib" &
            " --mm:arc" &
            " --threads:on" &
            " --passC:-fPIC" &
            " -d:release" &
            " --nimcache:" & root & "/target/nimcache" &
            " --out:" & root & "/release-arbiter/libarbiter_nim.a" &
            " src/arbiter_nim.nim"