#!/usr/bin/env bash

todotxt_lib_load()
{
  todotxt_env_init || true
}

todotxt_env_init()
{
  test -n "${todo_txt-}" || {
    test -e .todo.txt && todo_txt=.todo.txt || {
        test -e todo.txt && todo_txt=todo.txt || {
          return 1
        }
    }
  }
}

todotxt_tagged () # [File] Tag-Names...
{
  local p_ grep_a
  test -t 0 && {
    test -e "${1-}" && { grep_a="$1" ; shift; } || grep_a=$todo_txt
  } || grep_a=
  test $# -gt 0 || return 98
  test -n "${grep_f-}" || local grep_f=-n
  p_="$(match_grep "$1")"
  $ggrep $grep_f "^[0-9a-z -]*\b[^ ]*.*\\ \\(@\\|+\\)$p_\\(\\ \\|$\\)" $grep_a
}

#
