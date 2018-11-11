#!/bin/sh

# Get alias and show command, set (add/update) alias or list all
htd_alias() # [ ALIAS=CMD | ALIAS [ CMD ] ]
{
  test -n "$1" && {
    test -n "$2" || {
      fnmatch "*=*" "$1" && set -- "$(printf "$1" | cut -d'=' -f1)" \
        "$(printf "$1" | cut -d'=' -f2-)" || false
    }
  }

  test -n "$1" && {
    test -n "$2" && {
      alias_set "$@"
      return $?
    }

    note "Getting alias '$1'.."
    alias_get "$1"
    return $?
  }

  trueish "$all" && {
    note "Listing aliases for '$scriptname'.."
    scriptname='.*' alias_list
    return $?
  }
  note "Listing aliases for '$scriptname'.."
  alias_list
}
