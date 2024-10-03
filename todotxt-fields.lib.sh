#!/usr/bin/env bash

todotxt_fields_lib__load ()
{
  : "${ggrep:=grep}"
}


todotxt_field_chevron_refs ()
{
  $ggrep -oP '(?<=<)[^ ]+(?=>)'
}

todotxt_field_context_tags ()
{
  $ggrep -oP '\ @\K[^ ]+'
}

todotxt_field_context_tagrefs ()
{
  $ggrep -oP '\ \K@[^ ]+'
}

todotxt_field_hash_tags ()
{
  $ggrep -oP '(?<=#)[^ ]+(?= |$)'
}

todotxt_field_meta_tags ()
{
  $ggrep -oP '[A-Za-z0-9_-]+:[^ ]+'
}

todotxt_field_prios ()
{
  $ggrep -oP "^\\(${ttf_pp:-\K}[$TTXT_PRIOC]*(?=\\))"
}

todotxt_field_project_tags ()
{
  $ggrep -oP '\ \+\K[^ ]+'
}

todotxt_field_project_tagrefs ()
{
  $ggrep -oP '\ \K\+[^ ]+'
}

todotxt_field_square_refs ()
{
  $ggrep -oP '(?<=\[)[^ ]+(?=\])'
}

todotxt_field_single_rev9 ()
{
  $ggrep -oP '(?<=\`)[^\`]+(?=\`)'
}

todotxt_fielda_words ()
{
  test $# -eq 1 || return ${_E_GAE:?}
  # XXX: leading words only
  while test -n "${1:-}"
  do
    [[ "${1:?}" =~ (^|\ )([A-Za-z_-][A-Za-z0-9_-]+($|\ )).* ]] && {
      printf "%s" "${BASH_REMATCH[2]}"
  #    : "$(( 1 + ${#_} ))"
      set -- "${1:${#_}}"
    } || {

      break
      #return 1
    }
  done
}

#
