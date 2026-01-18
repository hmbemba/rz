import rz/core

proc err*[T](msg: cstring): Rz[T, string] {.inline.} =
    err[T]($msg)
