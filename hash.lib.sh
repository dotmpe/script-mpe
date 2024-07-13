#!/bin/sh

hash_lib__load ()
{
  lib_require ck
}


# FIXME: crc32: $(cksum.py -a rhash-crc32 "$1" | cut -d ' ' -f 1,2)

# Wrapper for generating hash/cksum from string
hash_str () # ~ <Algo> <String> [<Check>]
{
  ck_${1:?} - "${@:3}" <<< "${2:?"$(sys_exc hash-str "String expeced")"}"
}

# Output hash or checksum (in ASCII form) from input, and format. Default
# formatting as URN in the form of urn:<algo>:<cksum>.
# XXX: check mode/validate existing ckfile?
#
# ${out_fmt:=urn}
#
# to run checks with generated output see ck-run
hash_run () # ~ <Algo> [<Files...>]
{
  local algo=${1:?} hash
  shift
  case "$algo" in

    ( sha2 | sha256 )
        hash="$(shasum -a 256 "${@:--}")" || return
      ;;
    ( git | rhash-* )
        hash="$(cksum.py -a $algo "$@")" || return
      ;;
    ( ck )
        hash="$(htd__cksum "$@")" || return
      ;;
      * )
        exec=$(command -v ${algo}sum) &&
        hash="$($exec "${@:--}")" || return
  esac
  #"${urn:-true}"
  #&& sed 's/^/urn:'"$algo"':/g' || cat; }
}

#
