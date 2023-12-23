filereader_htd_lib__load()
{
  lib_require class-uc || return
  ctx_class_types=${ctx_class_types-}${ctx_class_types:+" "}\
ListFile\ TabFile\ FileReader
}


filereader_modeline ()
{
  test 1 -lt $# || return ${_E_MA:-194}
  file_modeline "$1" &&
  test -n "${filemode-}" &&
  str_fs=: str_wordsmatch "$filemode" "${@:2}"
}


class_FileReader__load ()
{
  Class__static_type[FileReader]=FileReader:Class
  declare -g -A FileReader__file
}

class_FileReader_ () # ~ <Instance-Id> .<Message-name> <Args...>
#   .__init__ <Instance-Type> <File-path> # constructor
{
  case "${call:?}" in

    ( .__init__ )
        test -f "${2:?}"
        FileReader__file[$id]=$_ &&
        $super.__init__ "${@:1:2}" "${@:3}" ;;

      * ) return ${_E_next:?};

  esac && return ${_E_done:?}
}


class_ListFile__load ()
{
  Class__static_type[ListFile]=ListFile:FileReader
}

class_ListFile_ () # ~ <Instance-Id> .<Message-name> <Args...>
#   .__init__ <Instance-Type> <File-path> # constructor
{
  case "${call:?}" in

      * ) return ${_E_next:?};

  esac && return ${_E_done:?}
}


class_TabFile__load ()
{
  Class__static_type[TabFile]=TabFile:FileReader
}

class_TabFile_ () # ~ <Instance-Id> .<Message-name> <Args...>
#   .__init__ <Instance-Type> <File-path> # constructor
{
  case "${call:?}" in

    ( .by-column )
        stderr echo TODO $* file=$($self.attr file FileReader)
      ;;

      * ) return ${_E_next:?};

  esac && return ${_E_done:?}
}

# Id: script-mpe/0.0.4-dev filereader-htd.lib.sh
