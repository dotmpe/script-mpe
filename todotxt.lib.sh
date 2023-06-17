#!/usr/bin/env bash

todotxt_lib__load ()
{
  : "${ggrep:=grep}"
}


todotxt_field_chevron_refs ()
{
  $ggrep -Po '(?<=<)[^ ]+(?=>)'
}

todotxt_field_context_tags ()
{
  $ggrep -Po '@[^ ]+'
}

todotxt_field_hash_tags ()
{
  $ggrep -Po '(?<=#)[^ ]+(?= |$)'
}

todotxt_field_meta_tags ()
{
  $ggrep -Po '[^ ]+:[^ ]+'
}

todotxt_field_project_tags ()
{
  $ggrep -Po '\+[^ ]+'
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
