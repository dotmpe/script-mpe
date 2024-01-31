
class_Context__load ()
{
  Class__libs[Context]=str,context,stattab-class
  Class__static_type[Context]=Context:StatTabEntry
  #: "${context_methods:=}"
  #stattab_var_keys
  #ctx_pclass_params=${ctx_pclass_params:-}${ctx_pclass_params:+ }$context_var_keys
}

class_Context_ () # (super,self,id,call) ~ <Args>
{
  str_wordmatch "${call:1}" ${context_methods:?} && {
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

      * ) return ${_E_next:?}

  esac && return ${_E_done:?}
}

#
