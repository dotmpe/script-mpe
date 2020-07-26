#!/bin/sh

# Statusdir - key-value storage, service wrappers


statusdir_lib_load()
{
  # Setup static STATUSDIR_ROOT env to directory (including trailing-/)
  true "${STATUSDIR_DEFAULT="$HOME/.statusdir"}"
  true "${STATUSDIR_ROOT:="$STATUSDIR_DEFAULT/"}"
  fnmatch "*/" "$STATUSDIR_ROOT" || STATUSDIR_ROOT="$STATUSDIR_ROOT/"
  export STATUSDIR_ROOT

  # Consider contents actual for 5 minutes after last update time by default
  true "${STATUSDIR_EXPIRY_AGE:=3600}"

  # Delete files 24hr after last access (by default) (ie. expiration age)
  true "${STATUSDIR_CLEAN_AGE:=86400}"
}

statusdir_lib_init()
{
  test "${statusdir_lib_init:-}" = "0" || {
    test -n "$INIT_LOG" && sd_log=$INIT_LOG || sd_log=$U_S/tools/sh/log.sh

    trueish "${choice_init-}" && {
      statusdir_init &&
      return $?
    }
    statusdir_check
  }
}

statusdir_check()
{
  test -e "${STATUSDIR_ROOT}logs"  || return
  test -e "${STATUSDIR_ROOT}index" || return
  test -e "${STATUSDIR_ROOT}tree"  || return
  test -e "${STATUSDIR_ROOT}cache"  || return
}

statusdir_init()
{
  test -e "${STATUSDIR_ROOT}logs"  || mkdir -p "${STATUSDIR_ROOT}logs"
  test -e "${STATUSDIR_ROOT}index" || mkdir -p "${STATUSDIR_ROOT}index"
  test -e "${STATUSDIR_ROOT}tree"  || mkdir -p "${STATUSDIR_ROOT}tree"
  test -e "${STATUSDIR_ROOT}cache"  || mkdir -p "${STATUSDIR_ROOT}cache"
}

statusdir_index() # Local-Name [Exists]
{
  { not_falseish "${2-}" || test -e "${STATUSDIR_ROOT}index/$1"
  } || {
    $LOG error "" "No such index" "${STATUSDIR_ROOT}index/$1"
    return 2
  }
  echo "${STATUSDIR_ROOT}index/$1"
}

# Load backend
statusdir_lib_start()
{
  # Get temporary dir: XXX move to fsdir
  test -n "$sd_tmp_dir" || sd_tmp_dir=$(setup_tmpd $base)
  test -n "$sd_tmp_dir" -a -d "$sd_tmp_dir" || error "sd_tmp_dir load" 1

  # Detect backend
  test -n "$sd_be" || {
    which redis-cli >/dev/null 2>&1 &&
      redis-cli ping >/dev/null 2>&1 &&
        sd_be=redis
  }

  test -n "$sd_be" || {
    which membash >/dev/null 2>&1 && sd_be=membash
  }

  # Set default be
  test -n "$sd_be" || sd_be=fsdir

  # Load backend
  lib_load statusdir-$sd_be
  test -n "$sd_be_name" && sd_be=$sd_be_name
}

statusdir_assert() # <rtype> <idxname>
{
  local rtype=$1
  shift
  test $# -gt 0 -a -n "${1-}" || set -- status.json
  $sd_be assert "$@"
}

# Unload backend
statusdir_lib_finish()
{
  test -n "$sd_tmp_dir" || error "sd_tmp_dir unload" 1
  # XXX: quick check for cruft. Is triggering on empty directories as well..
  #test "$(echo $sd_tmp_dir/*)" = "$sd_tmp_dir/*" \
  #  || warn "Leaving temp files in $sd_tmp_dir: $(echo $sd_tmp_dir/*)"
}

statusdir_list() #
{
  ls -la ${STATUSDIR_ROOT}{logs,index,tree}
}

# TODO: record status/id descriptor bits
statusdir_record()
{
  # Won't track or can't track
  true "${keep_track:=1}"
  trueish "$keep_track" || return 0
  test $# -gt 3 || return

  case "$1" in

      init ) # <Max-Age> <Id> -- <Cmd>
          # TODO: Add or replace descriptor bits for status record if different
        ;;

      set ) # <Max-Age> <Id> $status <Cmd>
          # TODO: update status bits for record
        ;;

      * ) return 95 ;
  esac
}

# XXX: test "$(test -t "statusdir")" != alias || unalias statusdir


# Execute command or function and cache stdout, or return existing cache.
# If the command errors, trash the result, keep quiet and return status.
# See statusdir-index-spec comments on the argument and expiration logic.
# TODO: combine with fsdir backend
statusdir() # [expiration-opts] [keep_err=0] ~ [<Max-Age> [<Expire-In>] ] [<Id>] [-- Cmd]
{
  test -n "$sd_log" || return 103
  local age_sec= expire_sec= cache_id= cache_file is=0

  while test $# -gt 0
    do
      test "$1" == "--" && break
      fnmatch "[@0-9]*" "$1" && {
        test -z "$age_sec" && age_sec=$1 || {
          test -z "$expire_sec" && expire_sec=$1 || return 98
        }
      } || {
        test -z "$cache_id" && cache_id=$1 || return 98
      }
      shift
    done
  test -n "$cache_id" || cache_id=$(mkvid "$*" && echo "$vid")
  test -n "$age_sec" || age_sec=$STATUSDIR_EXPIRY_AGE
  test -n "$expire_sec" || expire_sec=$STATUSDIR_CLEAN_AGE

  test "$1" == "--" || return 98
  shift

  #test $# -gt 3 && {
  #    statusdir_record init "$@" || return
  #  }

  true "${sd_base:="file"}"
  cache_file=${STATUSDIR_ROOT}${sd_base}/$cache_id

  true "${keep_err:=0}"
  true "${pass_err:=$keep_err}"

  sd_file_update()
  {
    { test -e "$cache_file" && newer_than "$cache_file" "$age_sec"
    } || {
      { "$@" > $cache_file ; } && is=0 || is=$?
      test $is -eq 0 && {
        $sd_log "note" "$cache_id" "Updated contents"
      } || {
        trueish "$keep_err" && {
          $sd_log "error" "$cache_id" "Keeping contents" "$is $*"
        } || {
          rm "$cache_file"
          $sd_log "error" "$cache_id" "Removed contents" "$is $*"
        }
      }
    }
  }
  sd_file_contents()
  {
    test $is -eq 0 && {
      cat "$cache_file"
    } || {
      trueish "$keep_err" && {
        trueish "$pass_err" && cat "$cache_file"
      }
      return $is
    }
  }
  sd_notify()
  {
    test $is -eq 0 && {
      # TODO: msg or mail after completion. This is a fire-and-forget
      # message.
      # TODO: record stat/id descr bits first, then track notification
      # with similar heuristics as expiry
      notify_desktop \
          "Statusdir" \
          "Ready ($sd_base/$cache_id)" \
          "New content for user-command '$*'."
    } || {
      notify_desktop \
          "Statusdir Error" \
          "Failed ($sd_base/$cache_id)" \
          "During user-command '$*'."
    }
  }

  case "$action" in

      file ) echo "$cache_file" ;;

      file-contents )
          sd_file_update "$@"
          echo "$cache_file"
          return $is
        ;;

      contents )
          sd_file_update "$@"
          sd_file_contents || return
        ;;

      notify )
          sd_file_update "$@"
          sd_notify
        ;;

      index ) # XXX: fix sd-file-update track lines, new/del/update
        ;;

      * ) $LOG "error" "Unknown action" "$action"
          return 96
        ;;

  esac
}

statusdir_cache()
{
  sd_base=cache action=contents statusdir "$@"
}

statusdir_cache_file()
{
  sd_base=cache action=file statusdir "$@"
}

statusdir_cache_notify()
{
  sd_base=cache action=notify statusdir "$@"
}
