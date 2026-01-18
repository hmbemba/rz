import std/[options]

type
    Rz* [T, E = string] = object
        ## A small Result-like type that avoids invalid states (variant object).
        case ok* : bool
        of true:
            val* : T
        of false:
            err* : E

runnableExamples:
    let a = Rz[int, string](ok: true,  val: 10)
    let b = Rz[int, string](ok: false, err: "nope")
    doAssert a.ok and a.val == 10
    doAssert (not b.ok) and b.err == "nope"

proc ok*[T](v: T): Rz[T, string] {.inline.} =
    Rz[T, string](ok: true, val: v)

proc err*[T](e: string): Rz[T, string] {.inline.} =
    Rz[T, string](ok: false, err: e)

proc err*[T, E](e: E): Rz[T, E] {.inline.} =
    Rz[T, E](ok: false, err: e)

proc errAs*[T, E, E2](dummy: Rz[T, E], e: E2): Rz[T, E2] {.inline.} =
    ## Build an Err Rz that matches T from `dummy` but uses a new error type E2.
    ## Used internally to implement `?` without relying on `result.val`.
    Rz[T, E2](ok: false, err: e)

proc getOr*[T, E](r: Rz[T, E], default: T): T {.inline.} =
    if r.ok: r.val else: default

proc getOrElse*[T, E](r: Rz[T, E], f: proc(e: E): T {.closure.}): T =
    if r.ok: r.val else: f(r.err)

template isOk*(r: untyped, body: untyped) =
    if (r).ok:
        body

template isErr*(r: untyped, body: untyped) =
    if not (r).ok:
        body

proc currentExcMsg*(): string =
    ## Cross-target exception formatting (kept centralized).
    let 
        e   = getCurrentException()
        msg = getCurrentExceptionMsg()
    when defined(js):
        result = msg
    else:
        result = repr(e) & ": " & msg
