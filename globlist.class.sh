
class_GlobList__load ()
{
  Class__libs[GlobList]=globlist
  Class__static_type[GlobList]=GlobList:ParameterizedClass
  : "${globlist_params:=defname basename prefix globlistkey groupkey ext ttl use_local_configdir use_cachedir build_main}"
  : "${globlist_methods:=base cache cachefile raw lookup mainfile maingroups paths pathspecs refresh stddef}"
  ctx_pclass_params=${ctx_pclass_params-}${ctx_pclass_params+" "}$globlist_params
}


class_GlobList_ () # :ParameterizedClass ~ <Instance-Id> .<Method> <Args...>
# Methods:
#   .GlobList <Concrete-Type> <Params|Class-params...>
#   .__GlobList
#
# GlobList routines:
#   base
#   cache
#   cachefile
#   raw
#   lookup
#   mainfile
#   maingroups
#   paths
#   pathspecs
#   refresh
#
# GlobList parameters:
#   defname
#   basename
#   prefix
#   globlistkey
#   groupkey
#   ext
#   ttl
#   use_local_configdir
#   use_cachedir
#   build_main
{
  test 1 -ge $# && {
    # Map some methods directly to params.
    static_ctx=globlist_ class_ParameterizedClass_cparams \
        globlist_params "${call:1}" "$@" && return
    test ${_E_next:?} -eq $? || return $_
  }
  str_globmatch " $globlist_methods " "* ${call:1} *" && {
    # And all these static globlist methods are already defined
    at_GlobList=$self globlist_${call:1} "$@"
    return
  }
  case "${call:?}" in
    ( .__init__ )
        ${self}_stddef &&
        $super$call "$@"
      ;;

    #( .class-context ) class.info-tree .class-context ;;
    #( .info | .toString ) class.info ;;

      * ) return ${_E_next:?}

  esac && return ${_E_done:?}
}

#
