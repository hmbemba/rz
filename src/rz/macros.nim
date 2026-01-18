import rz/core

template `?`*[T, E](r: Rz[T, E]): untyped =
    ## Early-return helper.
    ##
    ## Works inside procs that return Rz[SomeT, E].
    ## If `r` is Err -> returns Err from the current proc.
    ## If Ok -> yields the inner value.
    block:
        let tmp = r
        if not tmp.ok:
            return errAs(default(typeof(result)), tmp.err)
        tmp.val

template catch*[T, E](r: Rz[T, E], body: untyped): untyped =
    ## Evaluate Rz. If Err, inject `it` and run `body`.
    ## If Ok, yields the value.
    ##
    ## Example:
    ##   let n = catch(accessInt("nope")):
    ##       echo it.err
    ##       return err[string](it.err)
    block:
        let tmp = r
        if not tmp.ok:
            let it {.inject.} = tmp
            body
        else:
            tmp.val
