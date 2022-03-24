# Package

version       = "0.1.0"
author        = "Jake Leahy"
description   = "Creates an Atom feed from an ed stem forum (Was orignally RSS, hence the name)"
license       = "MIT"
srcDir        = "src"
bin           = @["edstemRSS"]


# Dependencies

requires "nim >= 1.5.1"
requires "mike" # I'll publish the actual lib when I ain't lazy
requires "norm >= 2.3.0"
requires "https://github.com/ire4ever1190/taskman"

task release, "build release binary":
    exec "nim c --gc:orc --deepcopy:on --opt:size -d:release -d:danger --out:runme src/edstemRSS.nim"
