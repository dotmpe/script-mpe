#!/bin/sh

## Handle shell user aliases

alias_exists()
{
  grep -q " \<$1\>=" ~/.alias
}

# Get any aliased command
alias_get()
{
  grep " \<$1\>=" ~/.alias | cut -d '=' -f 2-
}

alias_new()
{
  alias_exists "$1" && return 1
  echo "alias $1='$1'" >> ~/.alias
}

alias_update()
{
  false # TODO: add/update alias
}

alias_set()
{
  alias_exists "$1" && {
    alias_update "$@" ; return $?
  } || {
    alias_new "$@" ; return $?
  }
}

# FIXME: use aliases, basenames; also get list of all alias files to grep
# List aliases (for current script) TODO: should list subcmd aliases
alias_list()
{
  grep 'alias \<'"$scriptname"'\>=' ~/.alias |
      sed 's/^.* alias /alias /g' | grep -Ev '^(#.*|\s*)$' | while read -r _a A
  do
    a_id="$(echo "$A" | awk -F '=' '{print $1}')"
    a_shell="$(echo "$A" | awk -F '=' '{print $2}')"
    printf -- "%-18s%s\n" "$a_id" "$a_shell"
  done
}
