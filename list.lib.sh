#!/bin/sh

# Plain list/items helper tooling wip


# see pd-sketch.rst, and stdio.lib.sh
lst__inputs="arguments options paths files"
lst__outputs="passed skipped errored failed"


list_lib__load ()
{
  : "${uname:=$(uname -s)}"
  test -n "${hostname-}" || hostname="$(hostname -s | tr '[:upper:]' '[:lower:]')"
  test -n "${archive_dt_strf-}" || archive_dt_strf=%Y-%M-%dT%H:%m:%S
  test -n "${lst_base-}" || lst_base=htd
  test -n "${EDITOR-}" || EDITOR=nano
}

list_lib__init ()
{
  test -n "${SCRIPT_ETC-}" || {
      SCRIPT_ETC="$(lst_init_etc | head -n 1)" || ignore_sigpipe
  }
}

lst_load()
{
  sys_lib__load &&
  str_lib__load || return

  # NOTE: single session per proc. nothing sticky.
  test -n "$lst_session_id" || lst_session_id=$(get_uuid)

  test -x "$(which fswatch)" && lst_watch_be=fswatch \
    || {
      test -x "$(which inotifywait)" && lst_watch_be=inotify \
        || warn "No 'watch' backend"
    }

  # build ignore pattern file
  ignores_lib__load $lst_base || return

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

lst_init_etc()
{
  test ! -e etc/htd || echo $PWD/etc
  test -n "${1-}" || set -- "${scriptpath-}"
  test -n "$1" || set -- $(dirname "$0")
  test ! -e $1/etc/htd || echo $1/etc
  #XXX: test ! -e .conf || echo .conf
  #test ! -e $UCONF/htd || echo $UCONF
  #info "Set htd-etc to '$*'"
}


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
