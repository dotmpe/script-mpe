# Copyright: (C) 2025 qwrt <qwrt@t460s>
#
# Distributed under terms of the MIT license.

us_part_extra_pre=User-Script.Part.x-
us_part_extra_cnk=ff7d1508
us_part_extra_fun=(
  .iter-parts
)
declare -gA \
us_part_extra_als=(
  #[local:us_iter_parts]=.iter-parts
  #[_User_Script_iter_parts]=.iter-parts
)
declare -gA \
us_part_extra_ssc=(
)
declare -gA \
us_part_extra_hooks=(
#  [init]=\
#''
)
declare -gA \
us_part_extra_dep=(
  #[.iter-parts]='User-Script.OS.x.iter-source'
)

User-Script.Part.x-iter-parts ()
{
: about 'Helper to iterate over specific part elements'
: extended 'See also iter-sources'
  # TODO: utils and wrappers for DSL routines

  local -I US_SCR_{EXT,PATH,HASH,STAT}
  : "${US_SCR_EXT:=.group.bash .bash}"
  : "${US_SCR_PATH:=$SCRIPTPATH}"
  : "${US_SCR_HASH:=_os_script_path}"
  : "${US_SCR_STAT:=_os_script_load}"

  echo $FUNCNAME ${*}
  case ${1:?} in

  ( --export-global )
      User-Script.Part.x-iter-parts --match-dsl '_*' --export-dsl &&
      User-Script.Part.x-iter-parts --match-hooks 'global:*' --export-dsl
    ;;

  ( --match-dsv ) # domain specific variables: by-names and other special attribute or structure
    ;;

  ( --match-dsl ) # domain specific language: name aliases, and static/dynamic concepts
      : input "${2?$FUNCNAME${*:+ $*}: Part match}"
      local -n _ff7d1508_map1=${US_SCR_HASH}
      local -a partnames
      local -A dsl
      partnames=( "${!_ff7d1508_map1[@]}" )
      local name{,word} {a,s}name
      for name in "${partnames[@]}"
      do
        nameword=${name//[^A-Za-z0-9_]/_}
        local -n \
          partpre=${nameword}_pre \
          partdep=${nameword}_dep \
          partals=${nameword}_als partssc=${nameword}_ssc \
          als=${nameword}'_als["$aname"]' ssc=${nameword}'_ssc["$sname"]' \
          adep=${nameword}'_dep["$aname"]' sdep=${nameword}'_dep["$sname"]'
        local -a dslnames
        for aname in "${!partals[@]}"
        do
          # Skip single char and local names
          [[ ! ${aname:1} ]] && continue
          case "${aname}" in .* ) continue ;; esac
          globmatch "${2}" "${aname}" || continue
          dslnames+=( "$aname" )
          dsl["$name:als:$aname"]=$als
          [[ ! ${adep:+set} ]] || dsl["$name:dep:$aname"]=${sdep}
        done
        for sname in "${!partssc[@]}"
        do
          # Skip single char and local names
          [[ ! ${sname:1} ]] && continue
          case "${sname}" in .* ) continue ;; esac
          globmatch "${2}" "${sname}" || continue
          dslnames+=( "$sname" )
          dsl["$name:ssc:$sname"]=$ssc
          [[ ! ${sdep:+set} ]] || dsl["$name:dep:$sname"]=${sdep}
        done
        [[ ${dslnames[*]:+set} ]] || continue
        dsl["$name:pre"]=$pre
        dsl["$name:dsl"]="${dslnames[*]}"
      done
      >&2 declare -p dsl
      User-Script.Part.x-iter-parts "${@:3}"
    ;;

  ( --export-dsl )
      local dslkey part{name,key,dsn} partscr dep{,fun}
      local -n \
        dslnames='dsl["$partname:dsl"]' \
        dsldep='dsl["$partname:dep:$partdsn"]' \
        dss='dsl["$partname:$partkey:$partdsn"]'
      for partname in "${partnames[@]}"
      do
        for partdsn in ${dslnames}
        do
          for dep in ${dsldep}
          do
            [[ ${dep:0:1} == . ]] && depfun=$pre$dep || depfun=$dep
            declare -fx "$depfun"
          done
          for partkey in als ssc
          do
            [[ ${dss:+set} ]] || continue
            [[ ${dss:0:1} == . ]] && partscr=$pre$dss || partscr=$dss
            case $partkey in als )
              partscr=$partscr' "$@"'
            esac
            sh_fun "$partdsn" || {
              eval "$partdsn () { $partscr; }" || return
            }
            declare -fx "$partdsn"
          done
        done
      done
    ;;

    * ) return ${_E_nsk:-67}
  esac
}

# Id: extra,part,us                              vim:set ft=bash sw=2 sts=2 et:
