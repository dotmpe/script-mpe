
ctx_dirindex_lib__load ()
{
  lib_require class-uc || return
}


class_DirIndex__load ()
{
  Class__static_type[DirIndex]=DirIndex:ParameterizedClass
}

class_DirIndex_ () # :Class ~ <Instance-Id> .<Method> <Args...>
# Methods:
#   .DirIndex <Concrete-Type> <Params...>
#   .__DirIndex
{
  case "${call:?}" in

    ( .ood )
        $self.params
        TODO "test for files"
      ;;

    ( * ) return ${_E_next:?} ;;

  esac
  return ${_E_done:?}
}

#
