import std/[strutils, base64]
import rz/core

proc safeReadFile*(filePath: string): Rz[string, string] =
    try:
        ok(readFile(filePath))
    except CatchableError:
        err[string](currentExcMsg())

proc safeDecodeBase64*(s: string): Rz[string, string] =
    ## Removes newlines and base64-decodes.
    try:
        ok(s.replace("\n", "").decode())
    except CatchableError:
        err[string](currentExcMsg())
