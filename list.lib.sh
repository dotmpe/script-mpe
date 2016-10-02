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

  ignores_load lst

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


