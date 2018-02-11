#!/bin/sh


# see pd-sketch.rst, and stdio.lib.sh
lst__inputs="arguments options paths files"
lst__outputs="passed skipped errored failed"


list_lib_load()
{
  lst_preload
}

lst_preload()
{
  CWD=$(pwd -P)
  test -n "$EDITOR" || EDITOR=nano
  test -n "$hostname" || hostname="$(hostname -s | tr 'A-Z' 'a-z')"
  test -n "$uname" || uname=$(uname)
  test -n "$archive_dt_strf" || archive_dt_strf=%Y-%M-%dT%H:%m:%S
  test -n "$lst_base" || lst_base=htd

  test -n "$SCRIPT_ETC" || SCRIPT_ETC="$(lst_init_etc | head -n 1)"
}

lst_load()
{
  sys_lib_load
  str_lib_load

  # NOTE: single session per proc. nothing sticky.
  test -n "$lst_session_id" || lst_session_id=$(get_uuid)

  test -x "$(which fswatch)" && lst_watch_be=fswatch \
    || {
      test -x "$(which inotifywait)" && lst_watch_be=inotify \
        || warn "No 'watch' backend"
    }

  # build ignore pattern file
  ignores_lib_load $lst_base

  test ! -e "$IGNORE_GLOBFILE" || {
    IGNORE_GLOBFILE=$(eval echo \"\$$(str_upper "$base")_IGNORE\")
    lst_init_ignores
  }

  # Selective per-subcmd init
  for x in $(try_value "${subcmd}" load lst | sed 's/./&\ /g')
  do case "$x" in

    i ) # setup io files
        setup_io_paths -$subcmd-$lst_session_id
        export $lst__inputs $lst__outputs
      ;;

    #I ) # setup IO descriptors (requires i before)
    #    req_vars $(echo_local outputs) $(echo_local inputs)
    #    local fd_num=2 io_dev_path=$(io_dev_path)
    #    open_io_descrs
    #  ;;

  esac; done
}

lst_init_etc()
{
  test ! -e etc/htd || echo etc
  test -n "$1" || set -- $scriptpath
  test -n "$1" || set -- $(dirname "$0")
  test ! -e $1/etc/htd || echo $1/etc
  #XXX: test ! -e .conf || echo .conf
  #test ! -e $UCONFDIR/htd || echo $UCONFDIR
  #info "Set htd-etc to '$*'"
}


lst_unload()
{
  local subcmd_result=0

  for x in $(try_value "${subcmd}" load | sed 's/./&\ /g')
  do case "$x" in
    i ) # remove named IO buffer files; set status vars
        clean_io_lists $lst__inputs $lst__outputs
        std_io_report $lst__outputs || subcmd_result=$?
      ;;
    I ) # Named io is numbered starting with outputs and at index 3
        local fd_num=2
        close_io_descrs
        eval unset $(echo_local inputs) $(echo_local outputs)
      ;;
  esac; done

  unset \
    subcmd_pref \
    subcmd \
    def_subcmd \
    func_exists func \
    lst_session_id
  return $subcmd_result
}


# Update IGNORE_GLOBFILE lines
lst_init_ignores()
{
  # XXX: there's no unload, no way to warn about temp file being left
  # so instead for now insist there is a safe place to keep this file.
  test -n "$IGNORE_GLOBFILE" -a -e "$IGNORE_GLOBFILE" ||
       error "lst:init-ignores: expected $lst_base ignore dotfile ($IGNORE_GLOBFILE)" 1

  local suf=$1 ; shift

  test -n "$*" || {
      set -- "$@" global-drop global-purge
      test ! -e .git || set -- "$@" scm
      debug "Set ignores for $base ($IGNORE_GLOBFILE$suf) to '$*'"
    }
  {
    ignores_cat "$@"
  } >> $IGNORE_GLOBFILE$suf
  sort -u $IGNORE_GLOBFILE$suf | sponge $IGNORE_GLOBFILE$suf

  test -s $IGNORE_GLOBFILE$suf || {
    warn "Failed to find any ignore glob rules for $base"
    return 1
  }
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
