
ctx_ignores_lib__load ()
{
  lib_require globlist || return
  ctx_class_types=${ctx_class_types-}${ctx_class_types+" "}Ignores
  : "${ignores_methods:=find_expr find_files find_glob_expr stddef}"
}


class.Ignores () # :Globlist ~ <Instance-Id> .<Method> <Args...>
# Methods:
#   .Ignores <Concrete-Type> <Class-params|Params...>
#   .__Ignores
{
  local name=Ignores super_type=GlobList self super id=${1:?} m=$2
  shift 2
  self="class.$name $id "
  super="class.$super_type $id "

  fnmatch "* ${m:1} *" " $ignores_methods " && {
    # And all these static globlist methods are already defined
    ignores_${m:1} "$@"
    return
  }
  case "$m" in
    ( ".$name" )
        $super.$super_type "$@"
      ;;
    ( ".__$name" ) $super.__$super_type ;;

    ( .class-context ) class.info-tree .class-context ;;
    ( .info | .toString ) class.info ;;

    ( * ) $super"$m" "$@" ;;
  esac
}

#
