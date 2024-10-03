#!/usr/bin/env bash


## sh-sym: identify given symbol


# Show usage text or other information for shell keywords, buitins, other
# commands, aliases, but also paths and various sorts of packages, units and
# any item that is part of the current system. For this a set of callback
# handlers is needed that indicate what any given symbol represents and give
# sh-sym-ref clues how to handle it.

# E.g. this prints function source locations, the typeset for functions or
# complex aliases, includes the auto-complete declarations (interactive sessions
# only), and variable declarations matching <Name> as well.

# The sh-sym-det symbol is for an id-command mapping that serves as a registry
# for callback handlers that has two purposes: give a command to recognize and
# and Id for resulting set of symbols, the Id then is used to find a sh-sym-ref
# handler specific to that type of symbol.
declare -gA sh_sym_det=(
  [shell-lang-cmd]="command -v "
  [shell-lang-var]="declare -p"
  [shell-lang-ac]="complete -p"
  [sys-os-path]="sys_os_path"
  [sys-os-package]="sys_os_package" # Dont know of exact-match query for dpkg -S
)

std_if ()
{
  if_ok "$("$@")" && echo "$_"
}

sys_os_package ()
{
  : "${1:?"sys-os-package: symbol expected"}"
  [[ ${1:0:1} = / ]] && : "$1" || if_ok "$(command -v "$1")" || return
  test -n "$_" &&
  dpkg -S "$_"
}

sys_os_path ()
{
  [[ ${1:0:1} = / ]] && : "$1" || if_ok "$(sys_os_path_lookup "$1")" || return
  test -n "$_" &&
  file -s "$_"
}

# Unfortunately I dont know of any command to locate (any, ie. including
# non-executable) paths using PATH. So for that we need little routines such
# as these.
sys_os_path_lookup ()
{
  : "${1:?"sys-os-path-lookup: name or path reference expected"}"
  local __bd
  local -a __path
  sys_execmap __path echo "${PATH//:/$'\n'}" &&
  for __bd in "${__path[@]}"
  do
    [[ -e $__bd/$1 ]] || continue
    echo "$__bd/$1"
    return
  done
  false
}

sh_sym_ref__sys_os_package ()
{
  false
}

sh_sym_ref () # ~ <Names...>
{
  : source "sh-sym.sh"
  local __{cb{,i},sym,tp{,d}}
  for __sym in "$@"
  do
    stderr echo sym: $__sym
    for __cbi in ${!sh_sym_det[*]}
    do
      stderr echo cbi: $__cbi
      ! __tpd=$(std_noerr ${sh_sym_det[$__cbi]} "$__sym") || {
        stderr echo "found '$__cbi' symbol '$__sym' declared as '$__tpd'"
      }
    done
    continue

    ! __tp=$(type -t "$__sym") || {
      case "$__tp" in
        ( keyword | builtin )
            {
               if_ok "$(help "$__sym")" && echo -e "Usage: $_\n" || r=$?
               echo " \`$__sym' is a shell $__tp"
               ! if_ok "$(ac_spec "$__sym" | sed 's/^/  /')" ||
                 echo -e "\nCompletions:\n$_"
               ! if_ok "$(sh_vspec "$__sym")" ||
                 echo -e "\nVariable:\n  $_"
               return ${r-}
            } |
              IF_LANG=help \
              ${REFPAGER:-${PAGER:?}}
          ;;
        ( alias | function )
            sh_sym_typeset "$__sym" |
              IF_LANG=bash \
              ${REFPAGER:-${PAGER:?}}
          ;;
        ( file )
            {
              "$__sym" --help 2>&1 || r=$?
              test "$__sym" = "$(command -v $__sym)" ||
                echo -e "\n \`$__sym' is exec $_"
              ! if_ok "$(ac_spec "${__sym##*/}" | sed 's/^/  /')" ||
                echo -e "\nCompletions:\n$_"
               ! if_ok "$(sh_vspec "$__sym")" ||
                 echo -e "\nVariable:\n  $_"
              return ${r-}
            } | IF_LANG=help ${REFPAGER:-${PAGER:?}}
          ;;
        ( * )
            $LOG alert : "Symbol type?" "$__tp:$__sym" 1
      esac || return
      continue
    }

    ! if_ok "$(sh_vspec "$__sym")" || {
      : "$_
# Length: $( declare -n a=$__sym
sh_arr "$__sym" &&  {
  echo "${#a[@]}"
} || {
  echo "${#a}"
})"
      <<< "$_" IF_LANG=bash ${REFPAGER:-${PAGER:?}}
    }
  done
}
# Copy: Shell/symbol-reference


# Output script for function or alias, followed by a comment about the type. If
# the alias is single name, then recurse to that and display its type as well.
# The registered autocompletions for <name> (interactive mode only) are listed
# also. This does not look for variable names as well, as nothing special beyond
# what ``declare`` can print is known about those (see symbol-reference).
sh_sym_typeset () # ~ <Command-name>
{
  : source "sh-sym.sh"
  test $# -eq 1 || return ${_E_GAE:-193}
  sh_fun "${1:?}" && {
    local srcln srcfn
    if_ok "$(declare -F "$1")" &&
    read -r _ srcln srcfn <<< "$_" &&
    {
      echo "# Source <$srcfn> line $srcln"
      declare -f "$1"

      ac_spec "$1" || true

      sh_sym_fexp "$1"
    }

  } || {
    sh_als "$1" && {
      if_ok "$(sh_als_exp "$1")" || return
      als="$_"
      : "${als%% *}"
      : "${_## }"
      test "$als" = "$_" && {
        sh_sym_typeset "$als" || return
        echo "alias $1=$als"
      } || {
        echo "alias $1='${BASH_ALIASES[$1]}'"
        echo "# alias \`$1' expands to script:"
        echo "$als" | sed 's/^/   /'
      }
      ! if_ok "$(which -- "$1" 2>/dev/null)" ||
        echo "# shadows \`$1' exec $_"
      ac_spec "$1"

    } || {
      #sh_var "$1" && {
      #}

      if_ok "$(type "$1")" || return
      : "$_
$(ac_spec "$1" || true)"
      echo "# $_"
    }
  }
}
# Copy: Shell/symbol-typeset

# Print export line for function, if found exported for current env
sh_sym_fexp () # ~ <Name>
{
  : source "sh-sym.sh"
  if_ok "$(printf 'BASH_FUNC_%s%%%%=() { ' "${1:?}")" &&
  env | grep -q "$_" || return 0
  echo "declare -fx $1"
}

sh_vspec () # ~ <Shell-sym> # Print declaration for shell variable
{
  declare -p "${1:?}" 2>/dev/null
}

#
