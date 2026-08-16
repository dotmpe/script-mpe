# shell_quote --- quote an argument for safe use with the shell
function shell_quote(s,        # parameter
    SINGLE, QSINGLE, i, X, n, ret)   # locals
{
    if (s == "")
        return "\"\""

    SINGLE = "\x27"          # single quote
    QSINGLE = "\"\x27\""     # '"'"'
    n = split(s, X, SINGLE)

    ret = SINGLE X[1] SINGLE
    for (i = 2; i <= n; i++)
        ret = ret QSINGLE SINGLE X[i] SINGLE

    return ret
}
