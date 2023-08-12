
ctx_globlist_lib__load ()
{
  lib_require globlist ctx-pclass || return
  ctx_class_types=${ctx_class_types-}${ctx_class_types+" "}GlobList
  : "${globlist_params:=defname basename prefix globlistkey groupkey ext ttl use_local_configdir use_cachedir build_main}"
  : "${globlist_methods:=base cache cachefile raw lookup mainfile maingroups paths pathspecs refresh stddef}"
  ctx_pclass_params=${ctx_pclass_params-}${ctx_pclass_params+" "}$globlist_params
}


class.GlobList () # :ParameterizedClass ~ <Instance-Id> .<Method> <Args...>
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
  local name=GlobList super_type=ParameterizedClass self super id=${1:?} m=$2
  shift 2
  self="class.$name $id "
  super="class.$super_type $id "

  test 1 -ge $# && {
    # Map some methods directly to params.
    static_ctx=globlist_ class.ParameterizedClass.cparams \
        globlist_params "${m:1}" "$@" && return
    test ${_E_next:?} -eq $? || return $_
  }
  fnmatch "* ${m:1} *" " $globlist_methods " && {
    # And all these static globlist methods are already defined
    at_GlobList=$self globlist_${m:1} "$@"
    return
  }
  case "$m" in
    ( ".$name" )
        ${self}_stddef &&
        $super.$super_type "$@"
      ;;
    ( ".__$name" ) $super.__$super_type ;;

    ( .class-context ) class.info-tree .class-context ;;
    ( .info | .toString ) class.info ;;

    ( * ) $super"$m" "$@" ;;
  esac
}

#
