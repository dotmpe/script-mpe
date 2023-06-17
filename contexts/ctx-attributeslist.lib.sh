
ctx_attributeslist_lib__load ()
{
  lib_require ctx-globlist || return
  ctx_class_types=${ctx_class_types-}${ctx_class_types+" "}AttributesList
}


class.AttributesList () # :GlobList ~ <Instance-Id> .<Method> <Args...>
# Methods:
#   .AttributesList <Concrete-Type> <Params|Class-params...>
#   .__AttributesList
{
  local name=AttributesList super_type=GlobList self super id=${1:?} m=$2
  shift 2
  self="class.$name $id "
  super="class.$super_type $id "

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
