import rz/core

template retType(): untyped =
    when compiles(typeof(result).T):
        typeof(result).T
    else:
        typeof(result)

template `?`*[T, E](r: Rz[T, E]): untyped =
    block:
        let tmp = r
        if not tmp.ok:
            return errAs(default(retType()), tmp.err)
        tmp.val


template catch*[T, E](r: Rz[T, E], body: untyped): untyped =
    block:
        let tmp = r
        if not tmp.ok:
            let it {.inject.} = tmp
            body
        else:
            tmp.val
