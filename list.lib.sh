#!/bin/sh


# see pd-sketch.rst, and stdio.lib.sh
lst__inputs="arguments options paths files"
lst__outputs="passed skipped errored failed"


lst_preload()
{
  CWD=$(pwd -P)
  test -n "$EDITOR" || EDITOR=nano
  test -n "$hostname" || hostname="$(hostname -s | tr 'A-Z' 'a-z')"
  test -n "$uname" || uname=$(uname)
  test -n "$archive_dt_strf" || archive_dt_strf=%Y-%M-%dT%H:%m:%S
  test -n "$lst_base" || lst_base=htd

  test -n "$HTD_ETC" || HTD_ETC="$(lst_init_etc | head -n 1)"
}

lst_load()
{

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
  ignores_load $lst_base
  test -n "$IGNORE_GLOBFILE" -a -e "$IGNORE_GLOBFILE" ||
    error "expected $lst_base ignore dotfile" 1
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

lst_init_etc()
{
  test ! -e etc/htd || echo etc
  test ! -e $(dirname $0)/etc/htd || echo $(dirname $0)/etc
  #XXX: test ! -e .conf || echo .conf
  #test ! -e $UCONFDIR/htd || echo $UCONFDIR
  info "Set htd-etc to '$*'"
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

  local suf=$1
  {
    test -n "$1" && {
      shift
    } || {
      set -- "$@" global-drop global-purge
      test ! -e .git || set -- "$@" scm
      debug "Set ignores for $base ($IGNORE_GLOBFILE$suf) to '$*'"
    }

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
  error "deprecated" 124

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


