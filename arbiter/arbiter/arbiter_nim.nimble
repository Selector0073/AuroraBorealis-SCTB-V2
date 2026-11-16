# Package

version       = "0.1.0"
author        = "AuroraBorealis"
description   = "arbiter nim part"
license       = "MIT"
srcDir        = "src"
bin           = @["arbiter_updater", "connector"]


# Dependencies

requires "nim >= 2.4.0"


task release, "Compile all project binaries and pack into release-arbiter":
    let root = thisDir() & "/../.."
    let releaseDir = root & "/release-arbiter"

    mkDir releaseDir
    withDir thisDir():
        for b in bin:
            exec "nim c -d:release --opt:speed --outdir:" & releaseDir &
                " " & srcDir & "/" & b & ".nim"