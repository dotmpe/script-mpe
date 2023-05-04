#!/usr/bin/env bash

todotxt_lib__load ()
{
  todotxt_env_init || true
  : "${ggrep:=grep}"
}


todotxt_env_init () # [todo-txt] ~
{
  test -n "${todo_txt-}" || {
    test -e .todo.txt && todo_txt=.todo.txt || {
        test -e todo.txt && todo_txt=todo.txt || {
          return 1
        }
    }
  }
}

todotxt_tagged () # [todo-txt] ~ [<File>] <Tag-name>
{
  local p_ grep_a
  test -t 0 && {
    test -e "${1-}" && { grep_a="$1" ; shift; } || grep_a=$todo_txt
  } || grep_a=
  test -n "${grep_f-}" || local grep_f=-n
  p_="$(match_grep "${1:?}")"
  #$ggrep $grep_f '^[0-9a-z -]*\b[^ ]*.*\ \(@\|+\)'"$p_"'\(\ \|$\)' $grep_a
  $ggrep $grep_f '^[\t ]*[^#].*\ \(@\|+\)'"$p_"'\(\ \|$\)' $grep_a
}

#
