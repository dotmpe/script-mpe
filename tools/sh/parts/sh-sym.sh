
## sh-sym: identify given shell symbol

# Output script for function or alias, followed by a comment about the type. If
# the alias is single name, then recurse to that and display its type as well.
# The registered autocompletions for <name> (interactive mode only) are listed
# also. This does not look for variable names as well, as nothing special beyond
# what ``declare`` can print is known about those (see symbol-reference).
sh_sym_typeset () # ~ <Command-name>
{
  test $# -eq 1 || return ${_E_GAE:-193}
  sh_fun "${1:?}" && {
    local srcln srcfn
    if_ok "$(declare -F "$1")" &&
    read -r _ srcln srcfn <<< "$_" &&
    {
      echo "# Source <$srcfn> line $srcln"
      declare -f "$1"

      ac_spec "$1" || true
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

# Show usage text or other information for shell keywords, buitins and other
# commands, or print the typeset for functions or complex aliases. Also include
# the auto-complete declarations (interactive sessions only) and variable
# declarations matching <Name> as well.
sh_sym_ref () # ~ <Names...>
{
  local __sym __tp
  for __sym in "$@"
  do
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

sh_vspec () # ~ <Shell-sym> # Print declaration for shell variable
{
  declare -p "${1:?}" 2>/dev/null
}

#
