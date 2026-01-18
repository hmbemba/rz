import std/[sequtils, tables]
import rz/core

proc lastSafe*[T](s: seq[T]): Rz[T, string] =
    if s.len == 0:
        return err[T]("Seq has a len of 0")
    ok(s[^1])

proc at*[T](s: seq[T], idx: int): Rz[T, string] =
    if s.len == 0:
        return err[T]("Seq has a len of 0")
    if idx < 0 or idx >= s.len:
        return err[T]("Index out of range")
    ok(s[idx])

proc `@`*[T](s: seq[T], idx: int): Rz[T, string] {.inline.} =
    s.at(idx)

proc `@`*[V](t: Table[int, V], idx: int): Rz[V, string] =
    if t.len == 0:
        return err[V]("Table has a len of 0")
    if not t.hasKey(idx):
        return err[V]("Key not found: " & $idx)
    ok(t[idx])

template errIfEmptyStr*[T](s: string, msg: string = "String has a len of 0") =
    if s.len == 0:
        return err[T](msg)

template errIfAnyEmptyStr*[T](ss: seq[string], msg: string = "One or more strings are empty") =
    if ss.anyIt(it.len == 0):
        return err[T](msg)

template errIfEmpty*(s: cstring | string, body: untyped) =
    if s.len == 0:
        body
