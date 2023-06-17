
ctx_ignores_lib__load ()
{
  lib_require ctx-globlist || return
  ctx_class_types=${ctx_class_types-}${ctx_class_types+" "}Ignores
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

  case "$m" in
    ( ".$name" )
        $super.$super_type "$@"
      ;;
    ( ".__$name" ) $super.__$super_type ;;

    ( [._]find_expr ) ignores_find_expr "$@"
      ;;
    ( .class-context ) class.info-tree .class-context ;;
    ( .info | .toString ) class.info ;;

    ( * ) $super"$m" "$@" ;;
  esac
}

#
