import std/[json]
import rz/core

when not defined(nimscript):
    import jsony

proc accessKey*(j: JsonNode, key: string): Rz[JsonNode, string] =
    if j.kind != JObject:
        return err[JsonNode]("Not a JSON object")
    if not j.hasKey(key):
        return err[JsonNode]("Key not found: " & key)
    if j[key].kind == JNull:
        return err[JsonNode](key & " is null")
    ok(j[key])

proc accessKey*(j: JsonNode, key: string, kind: JsonNodeKind): Rz[JsonNode, string] =
    if j.kind != JObject:
        return err[JsonNode]("Not a JSON object")
    if not j.hasKey(key):
        return err[JsonNode]("Key not found: " & key)
    if j[key].kind != kind:
        return err[JsonNode](key & " is a " & $j[key].kind & " not a " & $kind)
    ok(j[key])

when not defined(nimscript):
    proc asObj*[T](s: string, obj: typedesc[T]): Rz[T, string] =
        try:
            ok(s.fromJson(obj))
        except CatchableError:
            err[T](currentExcMsg())

    proc asObj*[T](s: cstring, obj: typedesc[T]): Rz[T, string] =
        asObj($s, obj)
