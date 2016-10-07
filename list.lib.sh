#!/bin/sh


# see pd-sketch.rst, and stdio.lib.sh
lst__inputs="arguments options paths files"
lst__outputs="passed skipped errored failed"


lst_load()
{
  CWD=$(pwd -P)
  test -n "$EDITOR" || EDITOR=nano
  test -n "$hostname" || hostname="$(hostname -s | tr 'A-Z' 'a-z')"
  test -n "$uname" || uname=$(uname)
  test -n "$archive_dt_strf" || archive_dt_strf=%Y-%M-%dT%H:%m:%S

  sys_load
  str_load

  # NOTE: single session per proc. nothing sticky.
  test -n "$lst_session_id" || lst_session_id=$(get_uuid)

  test -x "$(which fswatch)" && lst_watch_be=fswatch \
    || {
      test -x "$(which inotifywait)" && lst_watch_be=inotify \
        || warn "No 'watch' backend"
    }

  # build ignore pattern file
  ignores_load lst
  test -n "$LST_IGNORE" -a -e "$LST_IGNORE" || error "expected $base ignore dotfile" 1
  lst_init_ignores

  # Selective per-subcmd init
  for x in $(try_value "${subcmd}" load | sed 's/./&\ /g')
  do case "$x" in

    i ) # setup io files
        setup_io_paths -$subcmd-$lst_session_id
        export $lst__inputs $lst__outputs
      ;;

    I ) # setup IO descriptors (requires i before)
        req_vars $(try_local outputs) $(try_local inputs)
        local fd_num=2 io_dev_path=$(io_dev_path)
        open_io_descrs
      ;;

  esac; done
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
        eval unset $(try_local inputs) $(try_local outputs)
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
  test -n "$IGNORE_GLOBFILE" -a -e "$IGNORE_GLOBFILE" \
    || error "expected existing IGNORE_GLOBFILE ($IGNORE_GLOBFILE)" 1
  test -n "$1" || {
    set -- scm
    test ! -e .attributes || set -- scm attributes
    debug "Set ignores for $base ($IGNORE_GLOBFILE) to '$*'"
  }

  for tag in $@
  do
    case $tag in
      scm )
          # TODO: why no list using frontend iso. GIT hardcoded. vc.sh
          for x in .gitignore .git/info/exclude
          do
            test -e $x || continue
            cat $x | grep -Ev '^(#.*|\s*)$' >> $IGNORE_GLOBFILE
          done
        ;;
      attributes )
          # see pd:list-paths opts parsing; could create sets of exclude globs
        ;;
    esac
  done

  test -s $IGNORE_GLOBFILE || {
    warn "Failed to find any ignore glob rules for $base"
    return 1
  }
}

# XXX: cons
htd_init_ignores()
{
  test -n "$IGNORE_GLOBFILE" || exit 1

  test -e $IGNORE_GLOBFILE.merged \
    && grep -qF $IGNORE_GLOBFILE.merged $IGNORE_GLOBFILE.merged || {
      echo $IGNORE_GLOBFILE.merged > $IGNORE_GLOBFILE.merged
    }

  #test -n "$pwd" || pwd=$(pwd)
  #test ! -e $HTDIR || {
  #  cd $HTDIR

  #  for x in .git/info/exclude .gitignore $IGNORE_GLOBFILE
  #  do
  #    test -s $x && {
  #      cat $x | grep -Ev '^(#.*|\s*)$'
  #    }
  #  done

  #  cd $pwd

  #} >> $IGNORE_GLOBFILE.merged
}

# Init empty find_ignores var
htd_find_ignores()
{
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

# return paths for names that exist along given path
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


