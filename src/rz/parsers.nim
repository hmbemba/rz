import std/[strutils]
import rz/core

proc accessInt*(s: string | cstring): Rz[int, string] =
    try:
        ok(parseInt($s))
    except CatchableError:
        err[int](currentExcMsg())

proc accessFloat*(s: string | cstring): Rz[float, string] =
    try:
        ok(parseFloat($s))
    except CatchableError:
        err[float](currentExcMsg())

proc accessBool*(s: string | cstring): Rz[bool, string] =
    try:
        ok(parseBool($s))
    except CatchableError:
        err[bool](currentExcMsg())
