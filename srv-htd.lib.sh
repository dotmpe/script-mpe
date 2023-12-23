srv_htd_lib__load()
{
  #lib_require metadir || return
  lib_require class-uc stattab-uc || return
  ctx_class_types=${ctx_class_types-}${ctx_class_types:+" "}SrvTab
  : "${SRVTAB:=${STATUSDIR_ROOT:?}index/srv.tab}"
}

srv_htd_lib__init ()
{
  test -z "${srv_htd_lib_init:-}" || return $_

  create srvtab SrvTab "$SRVTAB"
}


class_SrvTabEntry__load ()
{
  Class__static_type[SrvTabEntry]=SrvTabEntry:StatTabEntry
}

class_SrvTabEntry_ () # ~ <Instance-Id> .<Message-name> <Args...>
{
  case "${call:?}" in

    ( .local-dir ) # ~~ # Look for another entry in parent table that tags srv/<name>
        tagref=$(printf ' @%s\( \| .* \)host:%s\( \|$\)' $($self.var id) $HOST)
        : "$($self.src)"
        grep "$tagref" $_ | sed 's#^.* <\([^>]*\)/>.*#\1#'
      ;;

      * ) return ${_E_next:?};

  esac && return ${_E_done:?}
}

class_SrvTab__load ()
{
  Class__static_type[SrvTab]=SrvTab:StatTab
}

class_SrvTab_ () # ~ <Instance-Id> .<Message-name> <Args...>
#   .__init__ <Instance-Type> <Table> [<Entry-class>] # constructor
{
  case "${call:?}" in

    ( .__init__ )
        $super.__init__ "${@:1:2}" "${3:-SrvTabEntry}" "${@:4}" ;;

      * ) return ${_E_next:?};

  esac && return ${_E_done:?}
}

#
