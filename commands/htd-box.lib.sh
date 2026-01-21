#!/usr/bin/env bash

htd_box_host ()
{
  case "${1:?}" in
    ( --discover )
        local -n _274435c2_tags1=${2:?} _274435c2_tagref='_274435c2_pending[_274435c2_i]'
        local _274435c2_pending=( @System ) _274435c2_i=0
        #while [[ ${_274435c2_pending[*]} ]]
        while (( ${#_274435c2_pending[*]} ))
        do
          sh_fun "$_274435c2_tagref".report && _274435c2_tags1+=( "$_274435c2_tagref" )
          sh_fun "$_274435c2_tagref".discover && {
            "$_274435c2_tagref".discover _274435c2_pending || return
          }
          unset '_274435c2_pending[_274435c2_i]'
          ((_274435c2_i+=1))
        done
      ;;

    ( --generate-reports ) # ~ <Init>
        local -a _274435c2_tags2
        htd_box_host --discover _274435c2_tags2 || return

        : "${case_reader:=User.Script.Command.helplist-cases-a}"
        #: "${case_reader:=User.Script.Command.helplist-cases-b}"

        local tagref key reports data buffer init=${2:-0}
        for tagref in "${_274435c2_tags2[@]}"
        do
          # shellcheck disable=2013
          for key in $( grep -v '^[*-]' < <("${case_reader:?}" < <(declare -f "$tagref.report")))
          do
            for data in "${HTDOCS:?}/sysadmin/box/${HOSTNAME:?}/${key}" \
              {"${STATUSDIR_SHARE:?}","${STATUSDIR_CACHE:?}","${STATUSDIR_LOCAL:?}"}"/${HOSTNAME:?},${key}"
            do
              [[ -e "$data" ]] && break
            done

            ((init)) && {
              [[ -s $data ]] && continue
              "$tagref.report" "$key" >| "$data"
              : "$(wc -l "$data")"
              >&2 echo "Generated ${_%% *} lines for ${HOSTNAME} ${key@Q}"
            } || {
              buffer="${STATUSDIR_CACHE:?}/${HOSTNAME:?},${key}"
              "$tagref.report" "$key" >| "$buffer"
              diff -bqr "$data" "$buffer"
              [[ ! -h "$data" ]] || TODO "handle annex" || return
            }
          done
        done
      ;;

    ( --init ) # ~ <Stat-var> <Entry-var>
        htd_box_host --generate-reports 1
      ;;

    ( * ) return ${_E_nsa:?}
  esac
}

#
