#!/bin/sh

# Plain list/items helper tooling for htd.sh wip

# Created: 2016-10-02
# Updated: '16-'20, '22, '23


# [2016-10-02] see pd-sketch.rst, and stdio.lib.sh
lst__inputs="arguments options paths files"
lst__outputs="passed skipped errored failed"


list_lib__load ()
{
  #: "${archive_dt_strf:=%Y-%M-%dT%H:%m:%S}"
  : "${lst_base:=${base:-htd}}"
  : "${EDITOR:=nano}"
}

list_lib__init ()
{
  lib_require os || return
}


# [2023-09-12] Helper to build parser/processor
lst_data ()
{
  false
}

# [2023-09-12] Helper to build parser/processor
lst_data_context ()
{
  false
}

# [2016-12-24]
lst_load()
{
  # NOTE: single session per proc. nothing sticky.
  test -n "$lst_session_id" || lst_session_id=$(get_uuid)

  test -x "$(which fswatch)" && lst_watch_be=fswatch \
    || {
      test -x "$(which inotifywait)" &&
        lst_watch_be=inotify || warn "No 'watch' backend"
    }

  # build ignore pattern file
  ignores_init "$lst_base" || return

  test ! -e "$IGNORE_GLOBFILE" || {
    IGNORE_GLOBFILE=$(eval echo \"\$$(str_upper "$base")_IGNORE\")
    lst_init_ignores
  }

  # Selective per-subcmd init
  main_var flags "$baseids" flags "${flags_default-}" "$subcmd"
  for x in $(echo $flags | sed 's/./&\ /g')
  do case "$x" in

    i ) # setup io files
        setup_io_paths -$subcmd-$lst_session_id
        export $lst__inputs $lst__outputs
      ;;

    #I ) # setup IO descriptors (requires i before)
    #    req_vars $(main_local "" outputs) $(main_local "" inputs)
    #    local fd_num=2 io_dev_path=$(io_dev_path)
    #    open_io_descrs
    #  ;;

  esac; done
}

# [2016-10-02]
lst_unload()
{
  local subcmd_result=0

  main_var flags "$baseids" flags "${flags_default-}" "$subcmd"
  for x in $(echo $flags | sed 's/./&\ /g')
  do case "$x" in
    i ) # remove named IO buffer files; set status vars
        clean_io_lists $lst__inputs $lst__outputs
        std_io_report $lst__outputs || subcmd_result=$?
      ;;
    I ) # Named io is numbered starting with outputs and at index 3
        local fd_num=2
        close_io_descrs
        eval unset $(main_local "" inputs) $(main_local "" outputs)
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
lst_init_ignores ()
{
  local suf=${1?} cachef=$(ignores_cache_file "${@:2}")
  shift

  test $# -gt 0 || {
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
