#!/usr/bin/env bash

todotxt_fields_lib__load ()
{
  : "${ggrep:=grep}"
}


todotxt_readtab ()
{
  : "${1:?Table file path}"
  : "${2:?Record handler}"
  local -a todotxt_inline_code \
    todotxt_title_refs \
    todotxt_file_refs \
    todotxt_cite_refs \
    todotxt_context_tags \
    todotxt_project_tags \
    todotxt_hash_tags \
    todotxt_meta_tagspecs \
    todotxt_meta_tags \
    todotxt_{label,stat,key,line}
  while read -r todotxt_{stat,key,entry}
  do
    [[ ! ${todotxt_stat:+set} || "${todotxt_stat}" == "#"* ]] && continue

    [[ ${todotxt_key: -1} != : ]] || todotxt_key=${todotxt_key:1:-1}
    [[ ! ${todotxt_entry:+set} ]] || {
      todotxt_parserecord "${todotxt_entry}" || return
    }
    "${@:2}" || return

    unset todotxt_inline_code \
      todotxt_title_refs \
      todotxt_file_refs \
      todotxt_cite_refs \
      todotxt_context_tags \
      todotxt_project_tags \
      todotxt_hash_tags \
      todotxt_meta_tagspecs \
      todotxt_meta_tags \
      todotxt_label
  done < "${1}"
}

todotxt_parserecord ()
{
: param '~ <String>'
: input "${1:?Text data}"
  local rest=${1}
  while [[ ${rest:+set} ]]
  do
    { [[ $rest =~ ^\`\`([^\`]+)\`\`(\ (.+))?$ ]] &&
      todotxt_inline_code+=( "${BASH_REMATCH[1]}" )
    } || {
      [[ $rest =~ ^\`([^\`]+)\`(\ (.+))?$ ]] &&
        todotxt_title_refs+=( "${BASH_REMATCH[1]}" )
    } || {
      [[ $rest =~ ^\<([^\>]+)\>(\ (.+))?$ ]] &&
        todotxt_file_refs+=( "${BASH_REMATCH[1]}" )
    } || {
      [[ $rest =~ ^\[([^\]]+)\](\ (.+))?$ ]] &&
        todotxt_cite_refs+=( "${BASH_REMATCH[1]}" )
    } || {
      [[ $rest =~ ^@([^\ ]+)(\ (.+))?$ ]] &&
        todotxt_context_tags+=( "${BASH_REMATCH[1]}" )
    } || {
      [[ $rest =~ ^+([^\ ]+)(\ (.+))?$ ]] &&
        todotxt_project_tags+=( "${BASH_REMATCH[1]}" )
    } || {
      [[ $rest =~ ^\!([^\ ]+)(\ (.+))?$ ]] ||
      [[ $rest =~ ^([^:]+:[^\ ]+)*(\ (.+))?$ ]] &&
        todotxt_meta_tagspecs+=( "${BASH_REMATCH[1]}" )
    } || {
      [[ $rest =~ ^([^\ ]+)(\ (.+))?$ ]] ||
        failerr "Word expected ${rest@Q}" || return
      todotxt_label+=( "${BASH_REMATCH[1]}" )
    }
    [[ ${BASH_REMATCH[3]:+set} ]] &&
      rest=${BASH_REMATCH[3]} || unset rest
  done
  [[ ! ${todotxt_meta_tagspecs[*]:+set} ]] || {
    local ref key value
    for ref in "${todotxt_meta_tagspecs[@]}"
    do
      [[ $ref == '!'* ]] && continue # XXX: not sure what to do with these
      IFS=: read -r key value <<< "$ref"
      todotxt_meta_tags["${key,,}"]=$value
    done
  }
}

todotxt_fields ()
{
  : XXX "This requires bash to tokenize the line to words"
  local word
  for word
  do case "${word}" in
  ( '``'*'``' ) todotxt_inline_code+=( "${word:2:-4}" ) ;;
  ( '`'*'`' ) todotxt_title_refs+=( "${word:1:-2}" ) ;;
  ( '<'*'>' ) todotxt_file_refs+=( "${word:1:-2}" ) ;;
  ( '['*']' ) todotxt_cite_refs+=( "${word:1:-2}" ) ;;
  ( '@'* ) todotxt_context_tags+=( "${word:1}" ) ;;
  ( '+'* ) todotxt_project_tags+=( "${word:1}" ) ;;
  ( '#'* ) todotxt_hash_tags+=( "${word:1}" ) ;;
  ( *':'* ) todotxt_meta_tags+=( "${word}" ) ;;
  esac
  done
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
