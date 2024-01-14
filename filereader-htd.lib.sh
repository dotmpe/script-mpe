filereader_htd_lib__load()
{
  lib_require class-uc tabfile || return
  ctx_class_types=${ctx_class_types-}${ctx_class_types:+" "}\
ListFile\ TabFile\ FileReader
}


filereader_ ()
{
  TODO "put ${1:?} into cache"
}

# XXX: track/provide Id for input source
src_reader_ ()
{
  test -e "${1:?}" && {
    declare -g fr_src="$1"
    stdin_from_nonempty "$@" || return
  } || {
    declare -g fr_cmd="$1"
    stdin_from_ "$@"
  }
}


filereader_modeline ()
{
  test 1 -lt $# || return ${_E_MA:-194}
  file_modeline "$1" &&
  test -n "${filemode-}" &&
  str_fs=: str_wordsmatch "$filemode" "${@:2}"
}

# XXX:
filereader_define ()
{
  context_define
}

# Return E:next if given file does not have matching modeline.
# xxx: could prefix with file extension check, and even disable modeline/editor
# mode check, but this is more precise and simpler, and alt impl. are not needed
# for now. Relying on filename extension seems simple but is hardly usable as
# is.
filereader_skip ()
{
  declare ml_ft=( $(printf "ft=%s\n" ${tasks_filetypes:?}) )
  fml_lvar=true filereader_modeline "${1:?}" "${ml_ft[@]}" || {
    : "file:${1:?}"
    : "$_${fileid:+:id=$fileid}"
    : "$_${fileversion:+:ver=$fileversion}"
    : "$_${filemode:+:mode=$filemode}"
    $LOG info "" "Skipping" "$_"
    return 1
  }
}

# TODO: use file attribute to retrieve cached Id, or reset that from either
# modeline, or preproc line, or add a preproc line. With cache file identified,
# generate source Id list as well, and echo cache file path.
filereader_statusdir_cache ()
{
  declare sd_{{bd,},id} file{version,id,modeline}
  fml_lvar=true file_modeline "${1:?}" &&
  test -n "${fileid-}" &&
  test "${fileid:0:3}" = "SD:" && {
    sd=${fileid:3}
    str_globmatch "$sd" "*:*" && {
      sd_bdid=${sd%:*} sd_id=${sd#*:}
      sd_bd=${!sd_bdid:?Expected $sd_bdid env}/$metadir_default/cache
    } ||
      sd_id=${fileid:3} sd_bd=${STATUSDIR_ROOT}cache
  } ||
    sd_id=$fileid

  echo "$sd_bd/$sd_id"
}


class_FileReader__load ()
{
  Class__static_type[FileReader]=FileReader:Class
  declare -g -A FileReader__file=()
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

    ( .grep-tab )
        declare tabfile
        tabfile=$($self.attr file FileReader) &&
        < "$tabfile" tabfile_grep "$1" "${2:--val}"
      ;;

    ( .by-column-value )
        local grep_f=
        $self.grep-tab "$@"
      ;;

    ( .key-by-index ) # ~ <Match-col> <Val> <Select-col=0>
        declare tabfile
        tabfile=$($self.attr file FileReader) &&
        < "$tabfile" awk "{ if ( \$$1 == \"$2\" ) print \$${3:-0}; }"
      ;;

      * ) return ${_E_next:?};

  esac && return ${_E_done:?}
}

# Id: script-mpe/0.0.4-dev filereader-htd.lib.sh
