basedirtab_class__load()
{
  : "${UC_DIRTAB:=${UCONF:?}/user/dirtab}"
  : "${BASEDIRTAB:=${STATUSDIR_ROOT:?}index/basedirs.tab}"
}


basedirs_dump ()
{
	test $# -eq 0 -o "$*" = "--format=sh" || return ${_E_GAE:?}
  < "$BASEDIRTAB" awk '
    $2 !~ /^[A-Z]+$/ {
			# TODO mkid?
			next
		}
    $1 !~ /^ *#/ {
      if (a[$2]) next
			if (system("test -d " $1)==0) {
				a[$2]++
        b[length(a)-1]=$1
        c[length(a)-1]=$2
			}
    } END {
      for (i=0;i<length(a);i++) {
        print c[i] "=\"" b[i] "\""
      }
    }'
}


class_BaseDir__load ()
{
  # about "A directory value for a symbolic name" @BaseDir
  # description The value can or should exist depending on XXX: other attributes
  Class__static_type[BaseDir]=BaseDir:Class
}

class_BaseDir_ ()
{
  case "${call:?}" in

      * ) return ${_E_next:?}

  esac && return ${_E_done:?}
}


class_BaseDirTab__load ()
{
  # about "A simple format with at least two fields: a filepath with a symbolic name" @BaseDir
  Class__static_type[BaseDirTab]=BaseDirTab:TabFile
}

class_BaseDirTab_ ()
{
  case "${call:?}" in

    ( .__init__ )
        $super$call "${@:1:2}" "${3:-BaseDir}" "${@:4}" ;;

    ( .fetch ) # ~ <Path> <Symbol>
      ;;

      * ) return ${_E_next:?}

  esac && return ${_E_done:?}
}

#
