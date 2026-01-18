import unittest
import std/[options, json, tables, strutils, sequtils]
import ../src/rz

when not defined js:
    import tempfiles
    import os

type
    Person = object
        name: string
        age: int

    ApiResponse = object
        status: int
        message: string

# ============================================================================
# Core Module Tests
# ============================================================================

suite "rz/core - Basic Construction":
    test "ok() creates success result":
        let r = ok(42)
        check r.ok == true
        check r.val == 42

    test "err() creates failure result with string":
        let r = err[int]("something went wrong")
        check r.ok == false
        check r.err == "something went wrong"

    test "err() with custom error type":
        type MyError = enum
            NotFound, InvalidInput, Timeout
        
        let r = err[string, MyError](NotFound)
        check r.ok == false
        check r.err == NotFound

    test "ok with complex types":
        let p = Person(name: "Alice", age: 30)
        let r = ok(p)
        check r.ok
        check r.val.name == "Alice"
        check r.val.age == 30

    test "ok with seq":
        let r = ok(@[1, 2, 3, 4, 5])
        check r.ok
        check r.val.len == 5
        check r.val[2] == 3

    test "ok with nested types":
        let r = ok(@[ok(1), ok(2), err[int]("skip")])
        check r.ok
        check r.val.len == 3
        check r.val[0].val == 1
        check not r.val[2].ok

suite "rz/core - getOr and getOrElse":
    test "getOr returns value on Ok":
        let r = ok(100)
        check r.getOr(0) == 100

    test "getOr returns default on Err":
        let r = err[int]("failed")
        check r.getOr(999) == 999

    test "getOrElse returns value on Ok":
        let r = ok("hello")
        check r.getOrElse(proc(e: string): string = "default") == "hello"

    test "getOrElse calls function on Err":
        let r = err[string]("error code 42")
        let result = r.getOrElse(proc(e: string): string = "recovered from: " & e)
        check result == "recovered from: error code 42"

    test "getOrElse with stateful recovery":
        var callCount = 0
        let r = err[int]("oops")
        discard r.getOrElse(proc(e: string): int = 
            inc callCount
            -1
        )
        check callCount == 1

suite "rz/core - isOk and isErr templates":
    test "isOk executes body on success":
        var executed = false
        isOk ok(1):
            executed = true
        check executed

    test "isOk skips body on failure":
        var executed = false
        isOk err[int]("nope"):
            executed = true
        check not executed

    test "isErr executes body on failure":
        var executed = false
        isErr err[int]("failed"):
            executed = true
        check executed

    test "isErr skips body on success":
        var executed = false
        isErr ok(42):
            executed = true
        check not executed

    test "isOk/isErr with side effects":
        var log: seq[string] = @[]
        
        isOk ok("step1"):
            log.add("ok executed")
        
        isErr err[string]("step2"):
            log.add("err executed")
        
        check log == @["ok executed", "err executed"]

suite "rz/core - errAs":
    test "errAs converts error type":
        let original = err[int]("original error")
        let converted = errAs(original, 404)
        check not converted.ok
        check converted.err == 404

# ============================================================================
# Macros Module Tests
# ============================================================================

suite "rz/macros - ? operator":
    proc divideInts(a, b: int): Rz[int, string] =
        if b == 0:
            return err[int]("division by zero")
        ok(a div b)

    proc chainedDivision(a, b, c: int): Rz[int, string] =
        let first = ?divideInts(a, b)
        let second = ?divideInts(first, c)
        ok(second)

    test "? propagates Ok values":
        let r = chainedDivision(100, 10, 2)
        check r.ok
        check r.val == 5

    test "? early returns on first Err":
        let r = chainedDivision(100, 0, 2)
        check not r.ok
        check r.err == "division by zero"

    test "? early returns on second Err":
        let r = chainedDivision(100, 10, 0)
        check not r.ok
        check r.err == "division by zero"

    proc complexChain(input: string): Rz[int, string] =
        let parsed = ?accessInt(input)
        let doubled = parsed * 2
        if doubled > 100:
            return err[int]("too large")
        ok(doubled)

    test "? with parsing and validation":
        check complexChain("25").val == 50
        check not complexChain("invalid").ok
        check not complexChain("99").ok
        check complexChain("99").err == "too large"

    proc nestedQuestionMark(a, b, c: string): Rz[int, string] =
        let x = ?accessInt(a)
        let y = ?accessInt(b)
        let z = ?accessInt(c)
        ok(x + y + z)

    test "? multiple uses in one proc":
        check nestedQuestionMark("1", "2", "3").val == 6
        check not nestedQuestionMark("1", "x", "3").ok
        check not nestedQuestionMark("a", "2", "3").ok
        check not nestedQuestionMark("1", "2", "c").ok

suite "rz/macros - catch":
    proc parseWithDefault(s: string, default: int): int =
        catch(accessInt(s)):
            return default
    
    test "catch returns value on Ok":
        check parseWithDefault("42", 0) == 42

    test "catch executes body on Err":
        check parseWithDefault("not a number", -1) == -1

    proc parseWithLogging(s: string): Rz[int, string] =
        var errorLog = ""
        let n = catch(accessInt(s)):
            errorLog = it.err
            return err[int]("parse failed: " & errorLog)
        ok(n * 2)

    test "catch injects `it` with the Rz":
        let r = parseWithLogging("abc")
        check not r.ok
        check "parse failed" in r.err

    proc catchChain(a, b: string): Rz[int, string] =
        let x = catch(accessInt(a)):
            return ok(0)  # default to 0 on first failure
        let y = catch(accessInt(b)):
            return ok(x)  # return just x on second failure
        ok(x + y)

    test "catch with multiple recoveries":
        check catchChain("10", "20").val == 30
        check catchChain("bad", "20").val == 0
        check catchChain("10", "bad").val == 10
        check catchChain("bad", "bad").val == 0

# ============================================================================
# Combinators Module Tests
# ============================================================================

suite "rz/combinators - get and expect":
    test "get returns value on Ok":
        check ok(42).get() == 42

    test "get raises on Err":
        expect ValueError:
            discard err[int]("boom").get()

    test "expect returns value on Ok":
        check ok("hello").expect("should have value") == "hello"

    test "expect raises with custom message on Err":
        try:
            discard err[int]("underlying").expect("custom message")
            fail()
        except ValueError as e:
            check "custom message" in e.msg
            check "underlying" in e.msg

suite "rz/combinators - toOption":
    test "toOption converts Ok to Some":
        let opt = ok(42).toOption()
        check opt.isSome
        check opt.get == 42

    test "toOption converts Err to None":
        let opt = err[int]("nope").toOption()
        check opt.isNone

suite "rz/combinators - map":
    test "map transforms Ok value":
        let r = ok(10).map(proc(x: int): int = x * 2)
        check r.ok
        check r.val == 20

    test "map passes through Err":
        let r = err[int]("error").map(proc(x: int): int = x * 2)
        check not r.ok
        check r.err == "error"

    test "map changes type":
        let r = ok(42).map(proc(x: int): string = "value is " & $x)
        check r.ok
        check r.val == "value is 42"

    test "map chain":
        let r = ok(5)
            .map(proc(x: int): int = x + 1)
            .map(proc(x: int): int = x * 2)
            .map(proc(x: int): string = $x)
        check r.val == "12"

suite "rz/combinators - mapErr":
    test "mapErr transforms Err value":
        type DetailedError = object
            code: int
            message: string
        
        let r = err[int]("not found")
            .mapErr(proc(e: string): DetailedError = 
                DetailedError(code: 404, message: e))
        
        check not r.ok
        check r.err.code == 404
        check r.err.message == "not found"

    test "mapErr passes through Ok":
        let r = ok(42).mapErr(proc(e: string): string = "wrapped: " & e)
        check r.ok
        check r.val == 42

suite "rz/combinators - andThen":
    proc validatePositive(x: int): Rz[int, string] =
        if x > 0: ok(x) else: err[int]("must be positive")

    proc validateEven(x: int): Rz[int, string] =
        if x mod 2 == 0: ok(x) else: err[int]("must be even")

    test "andThen chains successful operations":
        let r = ok(4).andThen(validatePositive).andThen(validateEven)
        check r.ok
        check r.val == 4

    test "andThen short-circuits on first Err":
        let r = ok(-2).andThen(validatePositive).andThen(validateEven)
        check not r.ok
        check r.err == "must be positive"

    test "andThen short-circuits on second Err":
        let r = ok(3).andThen(validatePositive).andThen(validateEven)
        check not r.ok
        check r.err == "must be even"

    test "andThen propagates initial Err":
        let r = err[int]("initial").andThen(validatePositive)
        check not r.ok
        check r.err == "initial"

suite "rz/combinators - orElse":
    proc tryPrimary(x: int): Rz[int, string] =
        if x > 0: ok(x) else: err[int]("primary failed")

    proc tryFallback(e: string): Rz[int, string] =
        ok(0)  # always succeed with default

    test "orElse returns Ok unchanged":
        let r = ok(42).orElse(tryFallback)
        check r.ok
        check r.val == 42

    test "orElse tries fallback on Err":
        let r = tryPrimary(-1).orElse(tryFallback)
        check r.ok
        check r.val == 0

    test "orElse can also fail":
        proc alwaysFails(e: string): Rz[int, string] =
            err[int]("fallback also failed: " & e)
        
        let r = tryPrimary(-1).orElse(alwaysFails)
        check not r.ok
        check "fallback also failed" in r.err

suite "rz/combinators - tapOk and tapErr":
    test "tapOk executes side effect on Ok":
        var sideEffect = 0
        let r = ok(42).tapOk(proc(x: int) = sideEffect = x)
        check r.ok
        check r.val == 42
        check sideEffect == 42

    test "tapOk skips side effect on Err":
        var sideEffect = 0
        let r = err[int]("nope").tapOk(proc(x: int) = sideEffect = x)
        check not r.ok
        check sideEffect == 0

    test "tapErr executes side effect on Err":
        var errorLog = ""
        let r = err[int]("something broke").tapErr(proc(e: string) = errorLog = e)
        check not r.ok
        check errorLog == "something broke"

    test "tapErr skips side effect on Ok":
        var errorLog = ""
        let r = ok(42).tapErr(proc(e: string) = errorLog = e)
        check r.ok
        check errorLog == ""

    test "tap chaining for logging":
        var okLog: seq[int] = @[]
        var errLog: seq[string] = @[]
        
        discard ok(1)
            .tapOk(proc(x: int) = okLog.add(x))
            .tapErr(proc(e: string) = errLog.add(e))
        
        discard err[int]("fail")
            .tapOk(proc(x: int) = okLog.add(x))
            .tapErr(proc(e: string) = errLog.add(e))
        
        check okLog == @[1]
        check errLog == @["fail"]

# ============================================================================
# Parsers Module Tests
# ============================================================================

suite "rz/parsers - accessInt":
    test "parses valid integers":
        check accessInt("42").val == 42
        check accessInt("-17").val == -17
        check accessInt("0").val == 0
        check accessInt("+100").val == 100

    test "fails on invalid input":
        check not accessInt("").ok
        check not accessInt("abc").ok
        check not accessInt("12.5").ok
        check not accessInt("12abc").ok

    test "works with cstring":
        let cs: cstring = "123"
        check accessInt(cs).val == 123

suite "rz/parsers - accessFloat":
    test "parses valid floats":
        check accessFloat("3.14").val == 3.14
        check accessFloat("-2.5").val == -2.5
        check accessFloat("0.0").val == 0.0
        check accessFloat("1e10").val == 1e10

    test "parses integers as floats":
        check accessFloat("42").val == 42.0

    test "fails on invalid input":
        check not accessFloat("").ok
        check not accessFloat("abc").ok
        check not accessFloat("1.2.3").ok

suite "rz/parsers - accessBool":
    test "parses true values":
        check accessBool("true").val == true
        check accessBool("yes").val == true
        check accessBool("on").val == true
        check accessBool("1").val == true

    test "parses false values":
        check accessBool("false").val == false
        check accessBool("no").val == false
        check accessBool("off").val == false
        check accessBool("0").val == false

    test "fails on invalid input":
        check not accessBool("").ok
        check not accessBool("maybe").ok
        check not accessBool("2").ok

# ============================================================================
# Collections Module Tests
# ============================================================================

suite "rz/collections - lastSafe":
    test "returns last element of non-empty seq":
        check lastSafe(@[1, 2, 3]).val == 3
        check lastSafe(@["a", "b", "c"]).val == "c"

    test "fails on empty seq":
        check not lastSafe(newSeq[int]()).ok
        check "len of 0" in lastSafe(newSeq[string]()).err

suite "rz/collections - at and @":
    test "at returns element at valid index":
        let s = @[10, 20, 30, 40]
        check s.at(0).val == 10
        check s.at(2).val == 30
        check s.at(3).val == 40

    test "@ operator works like at":
        let s = @[10, 20, 30]
        check (s @ 0).val == 10
        check (s @ 1).val == 20
        check (s @ 2).val == 30

    test "at fails on empty seq":
        let s: seq[int] = @[]
        check not s.at(0).ok

    test "at fails on negative index":
        let s = @[1, 2, 3]
        check not s.at(-1).ok

    test "at fails on out of bounds index":
        let s = @[1, 2, 3]
        check not s.at(3).ok
        check not s.at(100).ok

suite "rz/collections - Table @":
    test "@ returns value for existing key":
        var t = initTable[int, string]()
        t[1] = "one"
        t[2] = "two"
        check (t @ 1).val == "one"
        check (t @ 2).val == "two"

    test "@ fails on empty table":
        let t = initTable[int, string]()
        check not (t @ 0).ok

    test "@ fails on missing key":
        var t = initTable[int, string]()
        t[1] = "one"
        check not (t @ 2).ok
        check "Key not found" in (t @ 99).err

suite "rz/collections - errIfEmpty templates":
    proc processString(s: string): Rz[int, string] =
        errIfEmptyStr[int](s, "input cannot be empty")
        ok(s.len)

    test "errIfEmptyStr returns early on empty":
        check not processString("").ok
        check processString("").err == "input cannot be empty"

    test "errIfEmptyStr continues on non-empty":
        check processString("hello").val == 5

    proc processStrings(ss: seq[string]): Rz[int, string] =
        errIfAnyEmptyStr[int](ss, "no empty strings allowed")
        ok(ss.len)

    test "errIfAnyEmptyStr returns early if any empty":
        check not processStrings(@["a", "", "c"]).ok
        check processStrings(@["a", "b", "c"]).val == 3

# ============================================================================
# JSON Module Tests
# ============================================================================

suite "rz/json - accessKey":
    test "accesses existing key":
        let j = %*{"name": "Alice", "age": 30}
        let r = j.accessKey("name")
        check r.ok
        check r.val.getStr == "Alice"

    test "fails on missing key":
        let j = %*{"name": "Alice"}
        check not j.accessKey("age").ok
        check "Key not found" in j.accessKey("missing").err

    test "fails on null value":
        let j = %*{"value": nil}
        check not j.accessKey("value").ok
        check "is null" in j.accessKey("value").err

    test "fails on non-object":
        let j = %*[1, 2, 3]
        check not j.accessKey("key").ok
        check "Not a JSON object" in j.accessKey("key").err

suite "rz/json - accessKey with kind":
    test "succeeds when kind matches":
        let j = %*{"count": 42, "name": "test"}
        check j.accessKey("count", JInt).ok
        check j.accessKey("name", JString).ok

    test "fails when kind doesn't match":
        let j = %*{"count": 42}
        let r = j.accessKey("count", JString)
        check not r.ok
        check "JInt" in r.err
        check "JString" in r.err

when not defined(nimscript):
    suite "rz/json - asObj":
        test "deserializes valid JSON":
            let jsonStr = """{"name": "Bob", "age": 25}"""
            let r = jsonStr.asObj(Person)
            check r.ok
            check r.val.name == "Bob"
            check r.val.age == 25

        test "fails on invalid JSON":
            let r = "not json".asObj(Person)
            check not r.ok

        test "fails on type mismatch":
            # jsony is lenient with missing fields, but fails on type mismatches
            let r = """{"name": 123, "age": "not a number"}""".asObj(Person)
            check not r.ok

        test "works with cstring":
            let cs: cstring = """{"name": "Cathy", "age": 35}"""
            let r = cs.asObj(Person)
            check r.ok
            check r.val.name == "Cathy"

# ============================================================================
# IO Module Tests (non-JS only)
# ============================================================================

when not defined(js):
    suite "rz/io - safeReadFile":
        test "reads existing file":
            let (f, path) = createTempFile("rz_test", ".txt")
            f.write("hello world")
            f.close()
            defer: removeFile(path)
            
            let r = safeReadFile(path)
            check r.ok
            check r.val == "hello world"

        test "fails on non-existent file":
            let r = safeReadFile("/nonexistent/path/file.txt")
            check not r.ok

    suite "rz/io - safeDecodeBase64":
        test "decodes valid base64":
            let encoded = "SGVsbG8gV29ybGQ="  # "Hello World"
            let r = safeDecodeBase64(encoded)
            check r.ok
            check r.val == "Hello World"

        test "handles newlines in input":
            let encoded = "SGVs\nbG8g\nV29ybGQ="
            let r = safeDecodeBase64(encoded)
            check r.ok
            check r.val == "Hello World"

        test "fails on invalid base64":
            let r = safeDecodeBase64("not valid base64!!!")
            check not r.ok

# ============================================================================
# Integration / Real-World Scenario Tests
# ============================================================================

suite "Integration - Config parsing pipeline":
    type
        Config = object
            host: string
            port: int
            debug: bool

    proc parseConfig(jsonStr: string): Rz[Config, string] =
        let parsed = try:
            parseJson(jsonStr)
        except JsonParsingError:
            return err[Config]("invalid JSON")
        
        let host = ?parsed.accessKey("host")
        let port = ?parsed.accessKey("port")
        let debug = ?parsed.accessKey("debug")
        
        ok(Config(
            host: host.getStr,
            port: port.getInt,
            debug: debug.getBool
        ))

    test "parses valid config":
        let json = """{"host": "localhost", "port": 8080, "debug": true}"""
        let r = parseConfig(json)
        check r.ok
        check r.val.host == "localhost"
        check r.val.port == 8080
        check r.val.debug == true

    test "fails on missing field":
        let json = """{"host": "localhost"}"""
        let r = parseConfig(json)
        check not r.ok

    test "fails on invalid JSON":
        let r = parseConfig("not json")
        check not r.ok
        check r.err == "invalid JSON"

suite "Integration - Data validation pipeline":
    type
        User = object
            name: string
            email: string
            age: int

    proc validateName(name: string): Rz[string, string] =
        if name.len == 0:
            return err[string]("name cannot be empty")
        if name.len > 50:
            return err[string]("name too long")
        ok(name)

    proc validateEmail(email: string): Rz[string, string] =
        if '@' notin email:
            return err[string]("invalid email format")
        ok(email)

    proc validateAge(age: int): Rz[int, string] =
        if age < 0:
            return err[int]("age cannot be negative")
        if age > 150:
            return err[int]("age seems unrealistic")
        ok(age)

    proc createUser(name, email: string, age: int): Rz[User, string] =
        let validName = ?validateName(name)
        let validEmail = ?validateEmail(email)
        let validAge = ?validateAge(age)
        ok(User(name: validName, email: validEmail, age: validAge))

    test "creates valid user":
        let r = createUser("Alice", "alice@example.com", 30)
        check r.ok
        check r.val.name == "Alice"

    test "fails on invalid name":
        check not createUser("", "a@b.com", 30).ok
        check createUser("", "a@b.com", 30).err == "name cannot be empty"

    test "fails on invalid email":
        check not createUser("Bob", "invalid", 25).ok
        check createUser("Bob", "invalid", 25).err == "invalid email format"

    test "fails on invalid age":
        check not createUser("Carol", "c@d.com", -5).ok
        check createUser("Carol", "c@d.com", -5).err == "age cannot be negative"

suite "Integration - Error recovery chain":
    proc fetchFromCache(key: string): Rz[string, string] =
        if key == "cached":
            ok("cached_value")
        else:
            err[string]("cache miss")

    proc fetchFromDb(key: string): Rz[string, string] =
        if key in ["db1", "cached"]:  # db has more
            ok("db_value")
        else:
            err[string]("not in db")

    proc fetchFromApi(key: string): Rz[string, string] =
        if key != "missing":
            ok("api_value")
        else:
            err[string]("not found anywhere")

    proc fetchWithFallback(key: string): Rz[string, string] =
        fetchFromCache(key)
            .orElse(proc(e: string): Rz[string, string] = fetchFromDb(key))
            .orElse(proc(e: string): Rz[string, string] = fetchFromApi(key))

    test "returns cached value first":
        check fetchWithFallback("cached").val == "cached_value"

    test "falls back to db":
        check fetchWithFallback("db1").val == "db_value"

    test "falls back to api":
        check fetchWithFallback("other").val == "api_value"

    test "fails if all sources fail":
        let r = fetchWithFallback("missing")
        check not r.ok
        check r.err == "not found anywhere"

suite "Integration - Batch processing with tap":
    test "logging successful operations":
        var successLog: seq[int] = @[]
        var errorLog: seq[string] = @[]
        
        let inputs = @["1", "2", "bad", "4", "nope"]
        var results: seq[Rz[int, string]] = @[]
        
        for input in inputs:
            let r = accessInt(input)
                .tapOk(proc(x: int) = successLog.add(x))
                .tapErr(proc(e: string) = errorLog.add(input & " failed"))
            results.add(r)
        
        check successLog == @[1, 2, 4]
        check errorLog.len == 2
        check results.len == 5

suite "Integration - Complex transformation chain":
    proc processNumber(input: string): Rz[string, string] =
        accessInt(input)
            .map(proc(x: int): int = x * 2)
            .map(proc(x: int): int = x + 10)
            .andThen(proc(x: int): Rz[int, string] =
                if x > 100:
                    err[int]("result too large")
                else:
                    ok(x)
            )
            .map(proc(x: int): string = "Result: " & $x)

    test "full chain success":
        check processNumber("20").val == "Result: 50"  # (20*2)+10 = 50

    test "chain fails on parse":
        check not processNumber("abc").ok

    test "chain fails on validation":
        check not processNumber("50").ok  # (50*2)+10 = 110 > 100
        check processNumber("50").err == "result too large"

# ============================================================================
# Edge Cases and Corner Cases
# ============================================================================

suite "Edge cases":
    test "empty string parsing":
        check not accessInt("").ok
        check not accessFloat("").ok
        check not accessBool("").ok

    test "whitespace handling":
        # Note: Nim's parseInt doesn't trim whitespace
        check not accessInt(" 42").ok
        check not accessInt("42 ").ok

    test "very large numbers":
        check accessInt("9223372036854775807").ok  # max int64
        check not accessInt("99999999999999999999999").ok

    test "nested Rz types":
        let nested: Rz[Rz[int, string], string] = ok(ok(42))
        check nested.ok
        check nested.val.ok
        check nested.val.val == 42

    test "chained getOr":
        let fallback1 = err[int]("first").getOr(err[int]("second").getOr(42))
        check fallback1 == 42

    test "seq of results - filtering":
        let results = @[ok(1), err[int]("a"), ok(2), err[int]("b"), ok(3)]
        let successes = results.filterIt(it.ok)
        let failures = results.filterIt(not it.ok)
        
        check successes.len == 3
        check failures.len == 2
        check successes.mapIt(it.val) == @[1, 2, 3]

when isMainModule:
    echo "Running rz test suite..."

discard """
Compile and run:
  nim c -r --hints:off tests/test.nim

With debug output:
  nim c -r -d:ic tests/test.nim

For JS target (subset of tests):
  nim js -r tests/test.nim
"""