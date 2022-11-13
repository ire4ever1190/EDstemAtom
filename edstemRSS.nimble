# Package

version       = "0.1.0"
author        = "Jake Leahy"
description   = "Creates an Atom feed from an ed stem forum (Was orignally RSS, hence the name)"
license       = "MIT"
srcDir        = "src"
bin           = @["edstemRSS"]


# Dependencies

requires "nim >= 1.6.0"
requires "mike#a87823f"
requires "norm == 2.6.0"
requires "taskman == 0.5.1"

task release, "build release binary":
    exec "nim c --gc:orc --deepcopy:on --opt:size -d:release -d:danger --out:runme src/edstemRSS.nim"
