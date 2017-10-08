#!/bin/bash

__box_()
{
  local box=$(which box)
  source $box
  source $(dirname $box)/str.lib.sh
}
__box_cmds()
{
  # use compgen to inspect all local functions, get command list from that
  local cmdids=$(compgen -A function | grep '^c_' | sed 's/c_//')
  local comps=
  for cmdid in $cmdids
  do
      local spec=( $(eval echo \$spc_$cmdid) )
      test -n "$spec" || continue
      comps="$comps $spec"
  done
  BOX_CMDS=$(echo $comps | tr '|' ' ')
}

__box_bash_auto_complete()
{
  local cur=${COMP_WORDS[COMP_CWORD]}
  local prev=${COMP_WORDS[COMP_CWORD-1]}

  __box_

  if [[ $COMP_CWORD -eq 1 ]]
  then
    __box_cmds
    COMPREPLY=( $(compgen -W "$BOX_CMDS" -- $cur) )
  else
    # cancel on other positions TODO: context compgen
    if [[ $COMP_CWORD -gt 1 ]]
    then
        case "$prev" in -e|edit ) ;; run ) ;;
        esac
    fi
    return 0
  fi

  # return on single result
  COMPREPLY_C=${#COMPREPLY[@]}
  if [[ $COMPREPLY_C -eq 1 ]]
  then
      return 0
  fi

  # Or print a help listing for found commands
  echo -e "\nFound $COMPREPLY_C commands for '$COMP_LINE':"
  for reply in ${COMPREPLY[@]}
  do
      test -n "$reply" || continue
      mkvid _$reply
      test -n "$vid" || exit 4
      als=$(eval echo "\$als$vid")
      test -z "$als" || continue # shortcut
      spc=$(eval echo "\$spc$vid")
      test -n "$spc" || {
          warn "no spec for $reply ($vid)"
          continue
      }
      man=$(eval echo "\$man_1$vid")
      if test "${#spc}" -ge 20
      then
          echo -e "  $spc "
          echo -e "\t\t\t$man"
      else
          echo -e "  $spc\t\t$man"
      fi
  done
  echo -en "\n$COMP_LINE"
  return 1
}


complete -F __box_bash_auto_complete box



