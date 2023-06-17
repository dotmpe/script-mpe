
ctx_dirindex_lib__load ()
{
  lib_require ctx-class || return
}


class.DirIndex.load ()
{
  true
}

class.DirIndex () # :Class ~ <Instance-Id> .<Method> <Args...>
# Methods:
#   .DirIndex <Concrete-Type> <Params...>
#   .__DirIndex
{
  local name=DirIndex super_type=Class self super id=${1:?} m=$2
  shift 2
  self="class.$name $id "
  super="class.$super_type $id "

  case "$m" in
    ( ".$name" )
          $super.$super_type "$@"
        ;;
    ( ".__$name" ) $super.__$super_type ;;

    ( .ood )
        $self.params
        TODO "test for files"
      ;;

    ( .class-context ) class.info-tree .class-context ;;
    ( .info | .toString ) class.info ;;

    ( * ) $super"$m" "$@" ;;
  esac
}

#
