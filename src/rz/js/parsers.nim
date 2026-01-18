import std/math
import rz/core

proc accessFloat*(s: cstring): Rz[float, string] =
    var x {.exportc: "rz_get_float".} = 0.0
    {.emit: "rz_get_float = parseFloat(`s`);".}
    if x.classify == fcNaN:
        err[float]("NaN")
    elif x.classify == fcInf:
        err[float]("Inf")
    else:
        ok(x)
