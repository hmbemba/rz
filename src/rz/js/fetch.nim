import std/[asyncdispatch, jsfetch]
import rz/core

when not defined(nimscript):
    import jsony

when not defined(nimscript):
    proc asObj*[T](r: jsfetch.Response, obj: typedesc[T]): Future[Rz[T, string]] {.async.} =
        try:
            let text: cstring = await r.text()
            ok(($text).fromJson(obj))
        except CatchableError:
            err[T](currentExcMsg())

    proc asObj*[T](futureResp: Future[jsfetch.Response], obj: typedesc[T]): Future[Rz[T, string]] {.async.} =
        try:
            let resp = await futureResp
            let text: cstring = await resp.text()
            ok(($text).fromJson(obj))
        except CatchableError:
            err[T](currentExcMsg())
