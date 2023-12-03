
context_class_lib__load ()
{
  lib_require context stattab-class || return
  ctx_class_types=${ctx_class_types-}${ctx_class_types:+" "}Context
  : "${context_methods:=}"
}

context_class_lib__init ()
{
  test -z "${context_class_lib_init:-}" || return $_
}


class_Context__load ()
{
  Class__static_type[Context]=Context:StatTabEntry
  #stattab_var_keys
  #ctx_pclass_params=${ctx_pclass_params:-}${ctx_pclass_params:+ }$context_var_keys
}

class_Context_ () # (super,self,id,call) ~ <Args>
{
  fnmatch "* ${call:1} *" " $context_methods " && {
    at_Context=$self context_${m:1} "$@"
    return
  }

  case "${call:?}" in

    ( .field ) # ~ <Key> [<Record>]
        local var val
        val=$(context_field "$@") &&
        var=ctx_${1//[:-]/_} &&
        declare -g $var=$val
      ;;
    ( .load ) # ~
      ;;

    ( * ) return ${_E_next:?} ;;
  esac || return
  return ${_E_done:?}
}

#
