#!/bin/sh

doc_name_arg()
{
  dir=$(dirname $1)
  test "." = "$dir" && {
    dir=$1
    name=$2
    shift 2
  } || {
    name=$(basename $1) # | tr 'A-Z' 'a-z')
    shift 1
  }
}

doc_find()
{
  # XXX: write a routine to detect dt, or emph tags
  files=$(grep -li '^'$name'$' $HOME/htdocs/${dir}/*.rst)
  test -z "$files" && {
      grep -li '\*'$name'\*' $HOME/htdocs/${dir}/*.rst
      files=$(grep -li '\*'$name'\*' $HOME/htdocs/${dir}/*.rst)
      test -n "$files" || return 1

  }
  file_cnt="$(echo $(echo $files | wc -w))"
  test $file_cnt -ge 0 || return 3
  test $file_cnt -eq 1 && file=$files || file="$(echo $files | sed 's/^\([^\ ]*\).*$/\1/')"

  test -e "$file" \
      || err '' "${bwhite}No doc for ${blue}$dir ${white}/ ${grn}$name${bwhite}. Stop." 1
  info "Found $file_cnt documents, opening first: $file"
}
