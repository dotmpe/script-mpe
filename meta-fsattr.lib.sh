
meta_fsattr_lib__load ()
{
  # XXX: requires os-als:loop-stat1
  lib_require sys str
}


# XXX: user. prefix is not removed or filtered upon, fields are not mapped
meta__fsattr__dump () # (out-fmt) ~ <File>
{
  local data
  data=$(meta__fsattr__raw "$@") &&
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

  ( * ) return ${_E_nsk:?}
  esac
}

meta__fsattr__get () # ~ <File> <Key>
{
  # XXX: unfortunately xattr does not have a -q flag or similar, and it does
  # not even use command status so this has to capture stderr.
  declare meta_fsattr_{stderr,stdout}
  capture_vars local:meta_fsattr_ xattr -p user.${2:?} "${1:?}" || return
  fnmatch "No such xattr: *" "${meta_fsattr_stderr}" && return 1 ||
  echo "${meta_fsattr_stdout}"
}

meta__fsattr__new () # ~ <File>
{
  TODO "@meta/fsattr.new"
}

meta__fsattr__set () # ~ <File> <Key> <Value>
{
  xattr -w user.${2:?} "${3:?}" "${1:?}"
}

meta__fsattr__raw () # ~ <File>
{
  xattr -l "${1:?}"
}

#
