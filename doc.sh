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

doc_list_all()
{
  ls $dir/$name.* 2> /dev/null && return
  grep -sni '^'$name'$' $HOME/htdocs/${dir}/*.rst && return
  grep -sni '\*'$name'\*' $HOME/htdocs/${dir}/*.rst && return
  note "no results"
  return 1
}

doc_try_fs()
{
  ls $dir/$name.* >/dev/null 2>&1 || return
  files=$(echo $dir/$name.*)
  file_cnt="$(echo $(echo $files | wc -w))"
}

doc_get_first()
{
  # ... detect dt, or emph tags
  files=$(grep -sli '^'$name'$' $HOME/htdocs/${dir}/*.rst)
  test -z "$files" && {
      files=$(grep -sli '\*'$name'\*' $HOME/htdocs/${dir}/*.rst)
      test -n "$files" || return 1
  }
  file_cnt="$(echo $(echo $files | wc -w))"
  test $file_cnt -gt 0 || return 1
}

doc_find()
{
  doc_try_fs || doc_get_first || return 1
  test $file_cnt -eq 1 \
      && file=$files || \
      file="$(echo $files | sed 's/^\([^\ ]*\).*$/\1/')"
  test -e "$file" \
      || err '' "${bwhite}No doc for ${blue}$dir ${white}/ ${grn}$name${bwhite}. Stop." 1
  info "Found $file_cnt documents, opening first: $file"
}

