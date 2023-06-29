
### Global function set for user-script

# For global functions in this repository see script-mpe.lib


# Build on uc:lib-load
# XXX: eg. use 'at_ Dev' to build ctx_dev handler?

# look for $<ctx>ctx and use value as handler, or source script <ctx>.sh
# and use at_<ctx> as handler. Continues shifting arguments until either
# exists. FIXME: should fail if none is found. Also should accumulate args,
# list scr_ctx if script was found and loaded and def_ctx for everything else.

at_ () # ~ <ctx> [<ctx|args..>]
{
  while test 0 -lt $#
  do
    : "${1:?at_ argument 1 expected}"

    ctxv=${1//[^A-Za-z0-9_]/_}ctx
    test -n "${!ctxv:-}" &&
    std_quiet declare -F "$_" && {
      set -- $_ "${@:2}"
      break
    }

    uc_script_load "${1:?}" || return
    ! std_quiet declare -F at_${1//[^A-Za-z0-9_]/_} || {
      set -- $_ "${@:2}"
      break
    }
    shift
  done
  test 0 -eq $# && return
  "$@"
}

#
