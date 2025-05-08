#!/bin/sh

metash_lib__load ()
{
  true
}

metash_lib__init ()
{
  test -z "${metash_lib_init-}" || return $_
  : "${METASH_GROUPS_DEFAULT:=}"
  : "${METASH_VALUE_A:=metash_dumpvalue -A}"
  : "${METASH_VALUE_G:=metash_dumpvalue -G}"
  : "${METASH_VALUE_a:=metash_dumpvalue -a}"
  : "${METASH_VALUE_d:=metash_dumpvalue -d}"
  : "${METASH_VALUE_n:=metash_dumpvalue -n}"
  : "${METASH_VALUE_s:=metash_dumpvalue -s}"
}

metash_cache () # ~ ...
{
  false
}

metash_debug () # ~ ...
{
  : "${DEBUG:-false}"
}

# TODO: declare basic elements?
metash_declare () #
{
  # eval "<func> () { <body> }"
  # alias <alias>=<script>
  # declare -g<flags> <var>=...

  declare -g${1:2} "${@:2}"
}

metash_defs () #
{
  [ $# -gt 0 ] || set -- $(metash_partids)
  local part valspec majtp
  for part
  do
    local -n type=TYPE_${part}
    : "${type:-v}"
    majtp=${_:0:1}
    local -n vcmd=METASH_VALUE_${majtp:?}
    [ -n "${vcmd-}" ] && {
      valspec=$(${vcmd} ${part})
    } || {
      local -n value=${part}
      [ -z "${value+set}" ] && valspec= || valspec=${value@Q}
    }
    echo "shdecl -${type:-v} ${part}=${valspec-}"
  done
}

metash_dumpvalue ()
{
  local part=${2:?} majtype=${1:1:1}
  local -n val=${part}
  # type=TYPE_${part}
  local -n spec=PART_${part}__${majtype}
  case "${majtype}" in
  ( A ) #
    echo "( $(for key in ${!val[*]}
      do
        echo -n "[\"$key\"]=${val[$key]@Q} "
      done))"
    return ;;
  ( G ) #
    echo "${spec@Q}"
    return ;;
  ( a ) #
    echo "( ${val[*]@Q} )"
    return ;;
  ( d ) # dynamic symbol
    # name could be alias, function maybe even temp/trans cmd?
    echo "${spec@Q}"
    return ;;
  ( n ) # by-name variable
    : "${spec// *}"
    echo "${_}"
    return ;;
  ( s ) # static script symbol
    echo "${spec@Q}"
    return ;;
  esac
  [ -n "$val" ] && {
    echo "${val@Q}"
  } || {
    : "${spec// *}"
    echo "${_@Q}"
  }
}

# metash-mk helper to build variable groups mainly
# -a append
# -l lower-case
# -p prefix
# -u upper-case
# -G make group (see mkgrp)
metash_mk () #
{
  local metash_prefix metash_upper metash_lower
  while true
  do case "${1:?}" in
    ( -a* ) metash_append=true && set -- -${1:2} "${@:2}" ;;
    ( -l* ) metash_lower=true && set -- -${1:2} "${@:2}" ;;
    ( -p* ) metash_prefix=true && set -- -${1:2} "${@:2}" ;;
    ( -u* ) metash_upper=true && set -- -${1:2} "${@:2}" ;;

    ( -G* ) metash_mkgrp "${@:2}"
        return
      ;;
       * ) $LOG alert : "Unrecognized make spec" "$1" 3 || return
    esac
  done
}

metash_mkgrp () # ~ <Id> <P-args...> [-- <P...> ]
{
  local grpid=${1:?} grpword parts update
  grpword=${grpid//[^A-Za-z0-9_]/_}
  [ "${metash_append:-false}" != true ] ||
    local -n parts="PART_${grpword}__G"
  [ -z "${parts-}" ] || update=true
  shift
  local I=1 o
  while test $# -gt 0
  do
    while test $I -lt $# -a "${!I}" != "--"
    do incr I
    done
    [ "${!I}" = "--" ] && o=$(( I - 1 )) || o=$I
    [ "$o" -eq 0 ] && {
      shift
      continue
    }
    [ "${metash_prefix:-false}" != true ] || set -- "$grpid/$1" "${@:2}"
    [ "${metash_upper:-false}" != true ] || set -- "${1^^}" "${@:2}"
    [ "${metash_lower:-false}" != true ] || set -- "${1,,}" "${@:2}"

    metash_mkprt "${@:1:$o}" || return
    parts=${parts-}${parts:+ }$1
    shift $I
    I=1
  done

  [ "${update:-false}" = true ] || {
    declare -g "PART_${grpword}__p=$grpid"
    #! metash_debug  ||
    #  >&2 declare -p "PART_${grpword}__p"
  }

  [ "${metash_prefix:-false}" != true ] &&
  declare -g "TYPE_${grpword}=G" ||
    declare -g "TYPE_${grpword}=Gp"
  #! metash_debug  ||
  #  >&2 declare -p "TYPE_${grpword}"

  [ "${metash_append:-false}" = true ] || {
    declare -g "PART_${grpword}__G=$parts"
    #! metash_debug  ||
    #  >&2 declare -g "PART_${grpword}__G"
  }
}

metash_mkprt () # ~ <Id> [<Type-spec>]
{
  local prtid=${1:?} prtword tpword
  [ "${2:--}" != - ] || set -- "" "" "${@:3}"
  prtword=${prtid//[^A-Za-z0-9_]/_}
  [ -n "${2-}" ] && tpword=${2:0:1} || tpword=v
  declare -g TYPE_${prtword}="${2}"
  declare -g PART_${prtword}__${tpword:?}="${*:3}"
  #! metash_debug  || {
  #  >&2 declare -p  \
  #    TYPE_${prtword} \
  #    PART_${prtword}__${tpword:?}
  #}
}

metash_partfields ()
{
  compgen -v PART_ | sed 's/PART_\(.*\)__\([A-Za-z]*\)/\1 \2/g'
}

metash_partids ()
{
  compgen -v TYPE_ | cut -c 6-
}

metash_parts ()
{
  [ $# -gt 0 ] || set -- $(compgen -v TYPE_)
  local typeref
  for typeref
  do
    [ -n "${!typeref}" ] && majtype=${!typeref:0:1} || majtype=v
    local -n mainspec=PART_${typeref:5}__${majtype}
    [ -n "${mainspec+set}" ] || {
      >&2 echo spec expected: mainspec=PART_${typeref:5}__${majtype}
      continue
    }
    echo "${typeref:5} ${!typeref} ${mainspec?Missing spec PART:${typeref:5}:${!typeref}}"
  done
}

metash_parttypes ()
{
  [ $# -gt 0 ] || set -- $(compgen -v TYPE_)
  local typeref
  for typeref
  do
    echo "${typeref:5} ${!typeref}"
  done
}

#
