basedir_htd_lib__load()
{
  lib_require class-uc filereader-htd || return
  ctx_class_types=${ctx_class_types-}${ctx_class_types:+" "}\
BaseDir\ BaseDirTab
  : "${BASEDIRTAB:=${STATUSDIR_ROOT:?}index/basedirs.tab}"
}

basedir_htd_lib__init ()
{
  test -z "${basedir_htd_lib_init:-}" || return $_

  create basedirtab BaseDirTab "$BASEDIRTAB"
}


class_BaseDir__load ()
{
  # about "A directory value for a symbolic name" @BaseDir
  # description The value can or should exist depending on XXX: other attributes
  Class__static_type[BaseDir]=BaseDir:Class
}

class_BaseDir_ () # ~ <Instance-Id> .<Message-name> <Args...>
#   .BaseDir <Type> [<Src:Line>] - constructor
{
  case "${call:?}" in

    ( .local-dir ) # ~~ # Look for another entry in parent table that tags basedir/<name>
        tagref=$(printf ' @%s\( \| .* \)host:%s\( \|$\)' $($self.var id) $HOST)
        : "$($self.src)"
        grep "$tagref" $_ | sed 's#^.* <\([^>]*\)/>.*#\1#'
      ;;

      * ) return ${_E_next:?}

  esac && return ${_E_done:?}
}

class_BaseDirTab__load ()
{
  # about "A simple format with at least two fields: a filepath with a symbolic name" @BaseDir
  Class__static_type[BaseDirTab]=BaseDirTab:TabFile
}

class_BaseDirTab_ () # ~ <Instance-Id> .<Message-name> <Args...>
#   .__init__ <Instance-Type> <Table> [<Entry-class>] # constructor
{
  case "${call:?}" in

    ( .__init__ )
        $super.__init__ "${@:1:2}" "${3:-BaseDir}" "${@:4}" ;;

      * ) return ${_E_next:?};

  esac && return ${_E_done:?}
}

#
