#!/bin/sh

# Statusdir - key-value storage, service wrappers


statusdir_lib_load ()
{
  # Setup static STATUSDIR_ROOT env to directory (including trailing-/)
  true "${STATUSDIR_DEFAULT="$HOME/.statusdir"}"
  true "${STATUSDIR_ROOT:="$STATUSDIR_DEFAULT/"}"
  fnmatch "*/" "$STATUSDIR_ROOT" || STATUSDIR_ROOT="$STATUSDIR_ROOT/"
  export STATUSDIR_ROOT

  # Re-validate timestamps for status at most every minute
  true "${STATUSDIR_CHECK_TTL:=60}"

  # Re-validate checksums for status at most every hour
  true "${STATUSDIR_VALID_TTL:=3600}"

  # Consider contents actual for 5 minutes after last update time by default
  true "${STATUSDIR_EXPIRY_AGE:=300}"

  # Delete files 24hr after last access (by default) (ie. expiration age)
  true "${STATUSDIR_CLEAN_AGE:=86400}"
}

statusdir_lib_init()
{
  test ${statusdir_lib_init:-1} -eq 0 || {
    test -n "$INIT_LOG" && sd_log=$INIT_LOG || sd_log=$U_S/tools/sh/log.sh

    test -d "${STATUSDIR_ROOT-}" &&
    statusdir_lib_start || return
  }
}

# Auto-detect backend, and load global settings. Already run by lib-load.
statusdir_lib_start() #
{
  statusdir_settings || return
  test -n "${sd_be:=""}" || {
    statusdir_autodetect || return
  }
}

# Auto-detect backend
statusdir_autodetect () #
{
  # Detect backend
  test -n "$sd_be" || {
    which redis-cli >/dev/null 2>&1 &&
      redis-cli ping >/dev/null 2>&1 &&
        sd_be=redis
  }

  test -n "$sd_be" || {
    which membash >/dev/null 2>&1 && sd_be=membash_f
  }

  # Set default be
  test -n "$sd_be" || sd_be=fsdir
}

# statusdir-start: For simple way to boot for sd backend after lib-load
statusdir_start () # [sd_be] ~ [Record-Key]
{
  local log_key="$scriptname:statusdir-start:${1-}"
  true "${sd_be:="fsdir"}" &&
  lib_require statusdir-$sd_be &&
  lib_init statusdir-$sd_be || return
  sd_be_h=sd_${sd_be}
  test $# -eq 0 && return
  local r=0
  $sd_be_h load "$@" || r=$? # Idem. to statusdir_run load "$@"
  log_key=$log_key\
      $LOG debug "" "Loaded backend '$sd_be' for" "$*"
  return $r
}

statusdir_check ()
{
  trueish "${choice_init-}" && {
    statusdir_run init || return $?
  } || {
    statusdir_run check || return $?
  }
}

statusdir_lookup_path () #
{
  cwd_lookup_path .statusdir .meta/stat
}

statusdir_lookup () # Record-Type Record-Name
{
  local LUP=$(statusdir_lookup_path)
  lookup_first=${lookup_first:-1} lookup_paths LUP $1/$2
}

# Defer to backend
statusdir_run () # [sd_be] ~ [Backend-Cmd] [Backend-Cmd-Args...]
{
  local sd_be_h=sd_${sd_be:=fsdir} a="${1-"load"}" ; shift
  local log_key="$scriptname:statusdir-run:$a"

  log_key=$log_key\
      $LOG debug "" "Trying backend '$sd_be:$a' handle..." "$*"
  $sd_be_h $a "$@"
}

statusdir_assert() # <rtype> <idxname>
{
  local rtype=$1
  shift
  test $# -gt 0 -a -n "${1-}" || set -- status.json
  $sd_be assert "$@"
}

# Unload backend
statusdir_finish()
{
  local sd_be_h=sd_${sd_be}
  #test -n "$sd_tmp_dir" || error "sd_tmp_dir unload" 1
  # XXX: quick check for cruft. Is triggering on empty directories as well..
  #test "$(echo $sd_tmp_dir/*)" = "$sd_tmp_dir/*" \
  #  || warn "Leaving temp files in $sd_tmp_dir: $(echo $sd_tmp_dir/*)"
  $sd_be_h unload || r=$? # statusdir_run unload
  $sd_be_h deinit || r=$? # statusdir_run deinit
}

# TODO: record status/... descriptor bits
# TODO: display ext/ttl/prefix/meta descriptor bits
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

statusdir_cache()
{
  sd_base=cache action=contents statusdir_mainnew "$@"
}

statusdir_cache_file()
{
  sd_base=cache action=file statusdir_mainnew"$@"
}

statusdir_cache_notify()
{
  sd_base=cache action=notify statusdir_mainnew "$@"
}

# Load global settings
statusdir_settings() #
{
  test -e ${STATUSDIR_ROOT}meta.sh || return
  source ${STATUSDIR_ROOT}meta.sh || return
}


# Execute command or function and cache stdout, or return existing cache.
# If the command errors, trash the result, keep quiet and return status.
# See statusdir-index-spec comments on the argument and expiration logic.
# TODO: combine with fsdir backend
statusdir_mainnew () # [expiration-opts] [keep_err=0] ~ [<Max-Age> [<Expire-In>] ] [<Id>] [-- Cmd]
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

# ID: statusdir.lib.sh
