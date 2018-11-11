#!/bin/sh


htd_argsv_list_session_start()
{
  true
}

htd_list_session_end()
{
  true
}


# XXX: cons
htd_init_ignores()
{
  error "deprecated" 123
}

# Init empty find_ignores var
htd_find_ignores()
{
  error "deprecated, see find_ignores usage" 124

  test -z "$find_ignores" || return

  test -n "$IGNORE_GLOBFILE" -a -e "$IGNORE_GLOBFILE.merged" && {
    find_ignores="$(find_ignores $IGNORE_GLOBFILE)"
  } || warn "Missing or empty IGNORE_GLOBFILE '$IGNORE_GLOBFILE'"

  find_ignores="-path \"*/.git\" -prune $find_ignores "
  find_ignores="-path \"*/.bzr\" -prune -o $find_ignores "
  find_ignores="-path \"*/.svn\" -prune -o $find_ignores "
}

htd_grep_excludes()
{
  test -n "$IGNORE_GLOBFILE" -a -e "$IGNORE_GLOBFILE" \
    || warn "Missing or empty IGNORE_GLOBFILE '$IGNORE_GLOBFILE'"
  grep_excludes=""$(echo $(cat $IGNORE_GLOBFILE.merged | \
    grep -Ev '^\s*(#.*|\s*)$' | \
    sed -E 's/^\//\.\//' | \
    sed -E 's/(.*)/ --exclude "*\1*" --exclude-dir "\1" /g'))
  grep_excludes="--exclude-dir \"*/.git\" $grep_excludes"
  grep_excludes="--exclude-dir \"*/.bzr\" $grep_excludes"
  grep_excludes="--exclude-dir \"*/.svn\" $grep_excludes"
}

# return paths for names that exist rootward along given dirpath
htd_find_path_locals()
{
  local name path stop_at
  name=$1
  path="$(cd $2;pwd)"
  test -z "$3" && stop_at= || stop_at="$(cd $3;pwd)"
  path_locals=
  while test -n "$path" -a "$path" != "/"
  do
    test -e "$path/$name" && {
        path_locals="$path_locals $path/$name"
    }
    test "$path" = "$stop_at" && {
        break
    }
    path=$(dirname $path)
  done
}

# migrate lines matching tag to to another file, removing the tag
# htd-move-tagged-and-untag-lines SRC DEST TAG
htd_move_tagged_and_untag_lines()
{
  test -e "$1" || error src 1
  test -n "$2" -a -d "$(dirname "$2")" || error dest 1
  test -n "$3" || error tag 1
  test -z "$4" || error surplus 1
  # Get task lines with tag, move to buffer without tag
  set -- "$1" "$2" "$(echo $3 | sed 's/[\/]/\\&/g')"
  grep -F "$3" $1 |
    sed 's/^\ *'"$3"'\ //g' |
      sed 's/\ '"$3"'\ *$//g' |
        sed 's/\ '"$3"'\ / /g' > $2
  # echo '# vim:ft=todo.txt' >>$buffer
  # Remove task lines with tag from main-doc
  grep -vF "$3" $1 | sponge $1
}

# migrate lines to another file, ensuring tag by strip and re-add
htd_move_and_retag_lines()
{
  test -e "$1" || error src 1
  test -n "$2" -a -d "$(dirname "$2")" || error dest 1
  test -n "$3" || error tag 1
  test -z "$4" || error surplus 1
  test -e "$2" || touch $2
  set -- "$1" "$2" "$(echo $3 | sed 's/[\/]/\\&/g')"
  cp $2 $2.tmp
  {
    # Get tasks lines from buffer to main doc, remove tag and re-add at end
    grep -Ev '^\s*(#.*|\s*)$' $1 |
      sed 's/^\ *'"$3"'\ //g' |
        sed 's/\ '"$3"'\ *$//g' |
          sed 's/\ '"$3"'\ / /g' |
            sed 's/$/ '"$3"'/g'
    # Insert above existing content
    cat $2.tmp
  } > $2
  echo > $1
  rm $2.tmp
}
