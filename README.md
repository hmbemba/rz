# rz

A lightweight Result type for Nim. Handle errors without exceptions.

## Install

```bash
nimble install rz
```

## Quick Start

```nim
import rz

# Create results
let good = ok(42)
let bad = err[int]("something went wrong")

# Check and extract
if good.ok:
    echo good.val  # 42

# Safe defaults
echo bad.getOr(0)  # 0

# Early return with ?
proc divide(a, b: int): Rz[int, string] =
    if b == 0:
        return err[int]("division by zero")
    ok(a div b)

proc calculate(x, y, z: int): Rz[int, string] =
    let first = ?divide(x, y)   # returns early if err
    let second = ?divide(first, z)
    ok(second)

echo calculate(100, 10, 2)  # ok(5)
echo calculate(100, 0, 2)   # err("division by zero")
```

## Core API

### Creating Results

```nim
# Success
let a = ok(42)              # Rz[int, string]
let b = ok("hello")         # Rz[string, string]
let c = ok(@[1, 2, 3])      # Rz[seq[int], string]

# Failure
let d = err[int]("failed")  # Rz[int, string]

# Custom error types
type MyError = enum NotFound, InvalidInput
let e = err[string, MyError](NotFound)  # Rz[string, MyError]
```

### Checking State

```nim
let r = ok(42)

# Direct field access
if r.ok:
    echo r.val
else:
    echo r.err

# Control flow templates
isOk r:
    echo "got value: ", r.val

isErr r:
    echo "got error: ", r.err
```

### Extracting Values

```nim
let r = ok(42)

# With default
r.getOr(0)  # 42, or 0 if err

# With fallback function
r.getOrElse(proc(e: string): int = 
    echo "Error was: ", e
    -1
)

# Panic on error (use sparingly)
r.get()                         # raises if err
r.expect("value was required")  # raises with custom message
```

## The `?` Operator

Early return on error. The bread and butter of `rz`:

```nim
proc fetchUser(id: int): Rz[User, string] =
    let data = ?httpGet("/users/" & $id)    # returns err early
    let parsed = ?parseJson(data)            # returns err early
    let user = ?validated(parsed)            # returns err early
    ok(user)
```

Equivalent to:

```nim
proc fetchUser(id: int): Rz[User, string] =
    let dataResult = httpGet("/users/" & $id)
    if not dataResult.ok:
        return err[User](dataResult.err)
    let data = dataResult.val
    # ... and so on
```

## The `catch` Template

Handle errors inline with access to the result via `it`:

```nim
proc parseOrDefault(s: string): int =
    catch(accessInt(s)):
        echo "Parse failed: ", it.err
        return 0

proc parseOrPropagate(s: string): Rz[int, string] =
    let n = catch(accessInt(s)):
        return err[int]("could not parse: " & it.err)
    ok(n * 2)
```

## Transformations

### map / mapErr

```nim
# Transform success value
ok(10)
    .map(proc(x: int): int = x * 2)
    .map(proc(x: int): string = $x)
# ok("20")

# Transform error value
err[int]("not found")
    .mapErr(proc(e: string): int = 404)
# err[int, int](404)
```

### andThen

Chain operations that might fail:

```nim
proc validatePositive(x: int): Rz[int, string] =
    if x > 0: ok(x) else: err[int]("must be positive")

proc validateEven(x: int): Rz[int, string] =
    if x mod 2 == 0: ok(x) else: err[int]("must be even")

ok(4)
    .andThen(validatePositive)
    .andThen(validateEven)
# ok(4)

ok(-2)
    .andThen(validatePositive)
    .andThen(validateEven)
# err("must be positive") - short circuits
```

### orElse

Fallback chains:

```nim
proc fromCache(key: string): Rz[string, string] = ...
proc fromDb(key: string): Rz[string, string] = ...
proc fromApi(key: string): Rz[string, string] = ...

proc fetch(key: string): Rz[string, string] =
    fromCache(key)
        .orElse(proc(e: string): Rz[string, string] = fromDb(key))
        .orElse(proc(e: string): Rz[string, string] = fromApi(key))
```

### tapOk / tapErr

Side effects without changing the result:

```nim
var log: seq[string] = @[]

ok(42)
    .tapOk(proc(x: int) = log.add("got: " & $x))
    .tapErr(proc(e: string) = log.add("failed: " & e))
    .map(proc(x: int): int = x * 2)
```

### toOption

```nim
import std/options

ok(42).toOption()        # some(42)
err[int]("x").toOption() # none(int)
```

## Parsers

Safe parsing that returns `Rz` instead of raising:

```nim
accessInt("42")       # ok(42)
accessInt("nope")     # err("...")

accessFloat("3.14")   # ok(3.14)
accessBool("true")    # ok(true)
```

## Collections

Safe access to sequences and tables:

```nim
let s = @[10, 20, 30]

s.lastSafe()   # ok(30)
s.at(1)        # ok(20)
s @ 1          # ok(20)  - operator syntax
s @ 99         # err("Index out of range")

@[].lastSafe() # err("Seq has a len of 0")

# Tables
var t = {1: "one", 2: "two"}.toTable
t @ 1          # ok("one")
t @ 99         # err("Key not found: 99")
```

### Guard Templates

```nim
proc process(s: string): Rz[int, string] =
    errIfEmptyStr[int](s, "input required")
    ok(s.len)

proc processAll(ss: seq[string]): Rz[int, string] =
    errIfAnyEmptyStr[int](ss)
    ok(ss.len)
```

## JSON

Safe JSON access:

```nim
import std/json

let j = %*{"name": "Alice", "age": 30}

j.accessKey("name")              # ok(JsonNode)
j.accessKey("missing")           # err("Key not found: missing")
j.accessKey("age", JInt)         # ok(JsonNode) - with kind check
j.accessKey("age", JString)      # err("age is a JInt not a JString")
```

Deserialization with jsony:

```nim
type User = object
    name: string
    age: int

let json = """{"name": "Bob", "age": 25}"""
json.asObj(User)  # ok(User(name: "Bob", age: 25))
```

## IO (native only)

```nim
safeReadFile("/path/to/file")    # ok(contents) or err(message)
safeDecodeBase64("SGVsbG8=")     # ok("Hello")
```

## JS Target

When compiling for JavaScript, `rz` provides:

- `rz/js/fetch` - async fetch helpers with jsony
- `rz/js/parsers` - JS-native float parsing
- `rz/js/helpers` - cstring error convenience

```nim
import std/[asyncdispatch, jsfetch]
import rz

type ApiResponse = object
    data: string

let resp = await fetch("/api/data")
let parsed = await resp.asObj(ApiResponse)  # Rz[ApiResponse, string]
```

## Real-World Example

```nim
import rz
import std/json

type
    Config = object
        host: string
        port: int
        debug: bool

proc loadConfig(path: string): Rz[Config, string] =
    let content = ?safeReadFile(path)
    
    let j = try:
        parseJson(content)
    except JsonParsingError:
        return err[Config]("invalid JSON")
    
    let host = ?j.accessKey("host")
    let port = ?j.accessKey("port")
    let debug = ?j.accessKey("debug")
    
    ok(Config(
        host: host.getStr,
        port: port.getInt,
        debug: debug.getBool
    ))

# Usage
let config = loadConfig("config.json")
    .tapErr(proc(e: string) = echo "Config error: ", e)
    .getOr(Config(host: "localhost", port: 8080, debug: false))
```

## Module Structure

```
rz
├── core         # Rz type, ok, err, getOr, isOk/isErr
├── macros       # ?, catch
├── combinators  # map, andThen, orElse, tap*, get, expect, toOption
├── parsers      # accessInt, accessFloat, accessBool
├── collections  # lastSafe, at, @, errIfEmpty*
├── json         # accessKey, asObj
├── io           # safeReadFile, safeDecodeBase64 (native only)
└── js/
    ├── fetch    # async fetch → Rz (JS only)
    ├── parsers  # JS float parsing (JS only)
    └── helpers  # cstring helpers (JS only)
```

Import everything:

```nim
import rz
```

Or pick what you need:

```nim
import rz/core
import rz/macros
import rz/combinators
```

## License

MIT