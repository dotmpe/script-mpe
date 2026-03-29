#!/usr/bin/env bash

### User auto-complete menu

# TODO: build completion as aggregate namespace, this requires merging several
# types of completions and managing potentially large sets. See sd:uc:context

# Build pseudo command for exploring completion.
alias user="echo user"

#declare -ga UC_AC_COMP
#declare -g UC_UM_DEFAULT=default

declare -gA __UC_MENU_USER
__UC_MENU_USER=(
  [compgen]=uc:um:compgen
  [alias]=uc_um_compgen:alias
)

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

__uc_ac_complete ()
{
  __uc_ac_readlines compgen "${@:?}"
}

__uc_ac_readlines ()
{
  mapfile -t COMPREPLY <<< "$("${@:?}")"
}

__uc_um_ac__simple_array_menu ()
{
  local -n COMP_WORD='COMP_WORDS[COMP_CWORD]'

  local mname=${3:-$1}
  local -n __menu="__UC_MENU_${mname^^}"
  [[ ${__menu[*]:+set} ]] || return

  [[ ${COMP_WORD:+set} ]] || printf '\n%s' "Completions for $mname menu"
  # shellcheck disable=2207 # Simple expansion is good enough here and makes
  # mechanism immediatly clear.
  COMPREPLY=( $(compgen -W "${!__menu[*]}" -- $COMP_WORD) )
  #__uc_ac_complete -W "${!__menu[*]}" -- "$COMP_WORD"
}

__uc_user_menu ()
{
  local -n COMP_WORD='COMP_WORDS[COMP_CWORD]'
  local uc_menu_{key,type}

  [[ $COMP_CWORD = 1 ]] && {
    uc_menu_type=array
    uc_menu_key=user

    # shellcheck disable=2207 # Simple expansion is good enough here and makes
    # mechanism immediatly clear.
    COMPREPLY=( $(compgen -W "${!__UC_MENU_USER[*]}" -- $COMP_WORD) )
    UC_COMP["$COMP_WORD"]=uc:um:root
    return

  } || {
    local -n comp_word='COMP_WORDS[i]'
    for (( i = 1; i < COMP_CWORD; i++ ))
    do
      key=${UC_COMP["$prev"]:?}
      declare -n arr=__${key//:/_}
      submenu_spec=${menu["$comp_word"]}

    done
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

complete -F __uc_um_ac__simple_array_menu user

# ex:ft=bash:
