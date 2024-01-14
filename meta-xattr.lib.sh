
meta_xattr_lib__load ()
{
  lib_require sys str
}


# XXX: user. prefix is not removed or filtered upon, fields are not mapped
meta_dump__xattr ()
{
  local data=$(meta_xattr__raw "$@")
  case "${out_fmt:-kv}" in
    ( fields )
        echo "$data"
      ;;
    ( tsv|pairs )
        echo "$data" | sed 's/: /\t/'
      ;;
    ( kv|kqv )
        echo "$data" | sed 's/: /=/' | str_quote_kvpairs
      ;;
    ( pkv|shkv )
        echo "$data" | conv_fields_shell
      ;;

    ( * ) return 4 ;;
  esac
}


meta_xattr__get () # ~ <File> <Key>
{
  # XXX: unfortunately xattr does not have a -q flag or similar, and it does
  # not even use command status so this has to capture stderr.
  typeset meta_xattr_{stderr,stdout}
  capture_vars local:meta_xattr_ xattr -p user.${2:?} "${1:?}" || return
  fnmatch "No such xattr: *" "${meta_xattr_stderr}" && return 1 ||
  echo "${meta_xattr_stdout}"
}

meta_xattr__set () # ~ <File> <Key> <Value>
{
  xattr -w user.${2:?} "${3:?}" "${1:?}"
}

meta_xattr__raw () # ~ <File>
{
  xattr -l "${1:?}"
}

#
