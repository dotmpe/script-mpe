#!/usr/bin/env bash

### User auto-complete menu

#shellcheck disable=1087

# Build pseudo command for exploring completion
alias user="echo user"

declare -ga UC_AC_COMP
declare -g UC_UM_DEFAULT=default
declare -gA __UC_UM_ROOT
__UC_UM_ROOT=(
  [compgen]=uc:um:compgen
  [alias]=uc:um:compgen:alias
)

# TODO: build from user (shell) alias table
#declare -gA __UC_UM_ALIAS
#__UC_UM_ALIAS=(
#)

# Simple user-menu with command-option map for compgen AC sets
declare -gA __UC_UM_COMPGEN
__UC_UM_COMPGEN=(
  ["alias"]="compgen:-a"
  ["command"]="compgen:-c"
  ["file"]="compgen:-f"
  ["directory"]="compgen:-d"
  ["export"]="compgen:-x"
  ["job"]="compgen:-j"
  ["variable"]="compgen:-v"
  ["function"]="compgen:-A function"
  ["service"]="compgen:-A service"
  ["arrayvar"]="compgen:-A arrayvar"
  ["builtin"]="compgen:-b"
  ["keywords"]="compgen:-k"
  ["user"]="compgen:-A user"
  ["group"]="compgen:-A group"
  ["default"]="uc:ac:compgen-all"
)

# TODO: need to handle associative arrays, could use maybe to map/translate
# trees?
#declare -gA __UC_UM_MENU
__UC_UM_MENU=(
    foo
    bar
    baz
    #[foo]=bar
    #[baz]=el
)
# XXX: no handling of whitespace...
__UC_UM_MENU_FOO=(
    "undsofort"
    "und so fort..."
    #[undso]="Und so"
)
#complete -p | while read -r _ opt key rest
#do
#    case "$opt" in
#        "-F" ) ac-fun $key $rest ;;
#    esac
#done

__uc_ac__bin ()
{
  mapfile COMPREPLY <<< "$("${@:?}")"
}

__uc_um_ac ()
{
  [[ $COMP_CWORD -gt 1 ]] && {
    false
  } || ctx=uc:um:root key=${COMP_WORDS[COMP_CWORD]}

  declare ref mvar mname=${1:-root} prev=${2:?} cur=${3:-}
  mvar=__UC_UM_${mname^^}
  #eval "menu=( \"\${${mvar}[@]}\" )"
  eval "ref=\${${mvar}[\$prev]}" &&
  echo "mvar=$mvar ref=$ref prev=$prev cur=$cur" >&2
  test -n "$ref" && {
    dir=${ref//:*}
    echo __uc_um_ac__${dir:?} ${ref/*:} >&2
    __uc_um_ac__${dir:?} ${ref/*:} || return
  }
  true
}

__uc_user_menu ()
{
  declare cur
  cur=${COMP_WORDS[COMP_CWORD]}
  # Only do root
  test $COMP_CWORD -eq 1 && {
    COMPREPLY=( $(compgen -W "${!__UC_UM_ROOT[*]}" -- $cur) )
    UC_COMP[$cur]=uc:um:root
    return
  }

  # Look at which level and context we are
  declare prev
  prev=${COMP_WORDS[$((COMP_CWORD-1))]}
  key=${UC_COMP["$prev"]:?}
  declare -n arr=__${key//:/_}

  test $COMP_CWORD -eq 2 && {
    declare ref dir
    __uc_um_complete "" "$prev" "$cur" || return
  }
  test $COMP_CWORD -gt 2 && {
    declare group
    group=${COMP_WORDS[$((COMP_CWORD-2))]}
    #stderr_ "group $group i: $COMP_CWORD words: ${COMP_WORDS[*]} cur=$cur prev=$prev"
    case "$group" in
        arrayvar )
                declare arr
                case "$(declare -p $prev | awk '{print $2}')" in
                    "-"*a* )
                            declare -a arr
                            arr=${!prev}
                            COMPREPLY=( $(compgen -W "${arr[*]}" -- "$cur") )
                            return
                        ;;

                    "-"*A* )
                            # Temp. arr. copy, might as well eval compgen...
                            #declare -A arr
                            #eval "arr=$(declare -p $prev |
                            #    sed 's/^declare -.* '$prev'=//')"
                            #COMPREPLY=( $(compgen -W "${!arr[*]}" -- "$cur") )
                            COMPREPLY=( $(eval "compgen -W \"\${!$prev[*]}\" -- \"$cur\"") )
                            return
                        ;;
                esac
                stderr_ "! $0: __uc_user_menu: Found no array declaration '$prev'"
                return 1
            ;;
    esac
  }

  declare prev decl avn=__UC_UM_$(echo ${COMP_WORDS[*]:1} | tr ' ' '_')
  avn=${avn^^}
  decl="$(declare -p $avn 2>/dev/null)" || {
    # Last word may be partial match in previous menu
    avn=__UC_UM_$(echo ${COMP_WORDS[*]:1:$((COMP_CWORD-1))} | tr ' ' '_')
    avn=${avn^^}
  }
  varopt="$(declare -p $avn 2>/dev/null | awk '{print $2}')" || {
    return
    #stderr_ "! $0: __uc_user_menu: No such menu array '$avn'" $? || return
  }
  prev=${COMP_WORDS[$((COMP_CWORD-1))]}
  case "$varopt" in
  "-"*a* )
          COMPREPLY=( $(eval "compgen -W \"\${$avn[*]}\" -- \"$cur\"") )
          return
      ;;

  "-"*A* )
          COMPREPLY=( $(eval "compgen -W \"\${!$avn[*]}\" -- \"$cur\"") )
          return
      ;;

  "-"* )
          stderr_ "! $0: __uc_user_menu: Not an menu array '$avn'" $? || return
          return
      ;;
  esac

  return 1
}

complete -F __uc_um_ac user

#
