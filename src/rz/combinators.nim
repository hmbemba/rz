import std/[options]
import rz/core

proc get*[T, E](r: Rz[T, E]): T =
    ## Panics if r is Err. Prefer `?`, getOr, getOrElse, or expect.
    if r.ok:
        r.val
    else:
        raise newException(ValueError, $r.err)

proc expect*[T, E](r: Rz[T, E], msg: string): T =
    if r.ok:
        r.val
    else:
        raise newException(ValueError, msg & ": " & $r.err)

proc toOption*[T, E](r: Rz[T, E]): Option[T] {.inline.} =
    if r.ok: some(r.val) else: none(T)

proc map*[T, U, E](r: Rz[T, E], f: proc(x: T): U {.closure.}): Rz[U, E] =
    if r.ok: ok(f(r.val))
    else:    err[U, E](r.err)

proc mapErr*[T, E, F](r: Rz[T, E], f: proc(e: E): F {.closure.}): Rz[T, F] =
    if r.ok: Rz[T, F](ok: true, val: r.val)
    else:    err[T, F](f(r.err))

proc andThen*[T, U, E](r: Rz[T, E], f: proc(x: T): Rz[U, E] {.closure.}): Rz[U, E] =
    if r.ok: f(r.val)
    else:    err[U, E](r.err)

proc orElse*[T, E](r: Rz[T, E], f: proc(e: E): Rz[T, E] {.closure.}): Rz[T, E] =
    if r.ok: r
    else:    f(r.err)

proc tapOk*[T, E](r: Rz[T, E], f: proc(x: T) {.closure.}): Rz[T, E] =
    if r.ok:
        f(r.val)
    r

proc tapErr*[T, E](r: Rz[T, E], f: proc(e: E) {.closure.}): Rz[T, E] =
    if not r.ok:
        f(r.err)
    r
