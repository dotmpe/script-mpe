#!/bin/sh


# FIXME: crc32: $(cksum.py -a rhash-crc32 "$1" | cut -d ' ' -f 1,2)


hash_str () # ~ <Algo> <String>
{
  printf '%s' "${1:?}" | urn=false hash_run ${2:?} - | cut -d ' ' -f 1
}

# output as urn:$algo:<cksum> unless ${urn:-false}
# to run checks with generated output see ck-run
hash_run () # ~ <Algo> <Files...>
{
  local algo=${1:?}
  shift
  { case "$algo" in

      ( sha2 | sha256 )
            shasum -a 256 "$@"
          ;;
      ( git | rhash-* )
            cksum.py -a $algo "$@"
          ;;
      ( ck )
            htd__cksum "$@"
          ;;
      ( * )
            exec=$(command -v ${algo}sum) || return
            ${ext}sum -c "$@"
          ;;
    esac
  } | { ${urn:-true} && sed 's/^/urn:'"$algo"':/g' || cat; }
}

#
