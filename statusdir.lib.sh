#!/bin/sh

## Key-value storage/service wrappers


statusdir_lib__load ()
{
  lib_require sys || return

  # Setup static STATUSDIR_ROOT env to directory (including trailing-/)
  true "${STATUSDIR_DEFAULT="$HOME/.local/statusdir"}"
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

statusdir_lib__init ()
{
  test ${statusdir_lib_init:-1} -eq 0 || {
    test -n "${INIT_LOG:-}" && sd_log=$INIT_LOG || sd_log=$U_S/tools/sh/log.sh

    test -d "${STATUSDIR_ROOT-}" || {
      $sd_log  "error" "" "No root directory" "$STATUSDIR_ROOT"
      return 1
    }
    statusdir_lib_start ||
        $sd_log error "" "Failed to start" "E$?" $? || return
  }
}

# Auto-detect backend, and load global settings. Already run by lib-load.
statusdir_lib_start() #
{
  statusdir_settings || return
  test -n "${sd_be:=""}" || {
    statusdir_autodetect || {
      $sd_log  "error" "" "Cannot auto-detect usable backend"
      return 4
    }
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

# Generate local PWD path for statusdir folder/file lookup
statusdir_lookup_path () #
{
  #cwd_lookup_path .meta/stat .local/statusdir .statusdir
  user_lookup_path $HOME/.local/statusdir -- .meta/stat .local/statusdir .statusdir
}

# Lookup statusdir folders/files on local PWD path
statusdir_lookup () # ~ <File-name> [<Type>]
{
  test $# -ge 1 -a $# -le 2 -a -n "${1-}" || return 64
  test $# -gt 1 || set -- "$1" ""
  : "$(statusdir_lookup_path)" &&
  LUP=${_//$'\n'/:} lookup_first=${lookup_first:-true} lookup_test="" \
    lookup_path LUP ${2:-index}/${1:?}
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
statusdir_record () #
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

# Load global settings # XXX: builtins so could use PATH= command -v as well
# ie. local PATH without tainting global env
statusdir_settings () # ~
{
  test -e ${STATUSDIR_ROOT}meta.sh || {
    $sd_log  "error" "" "Cannot find root settings"
    return 2
  }
  source ${STATUSDIR_ROOT}meta.sh || {
    $sd_log  "error" "" "Cannot load root settings"
    return 3
  }
}


# Execute command or function and cache stdout, or return existing cache.
# If the command errors, trash the result, keep quiet and return status.
# See statusdir-record-spec comments on the argument and expiration logic.
# TODO: combine with fsdir backend
statusdir_record () # [expiration-opts] [keep_err=0] ~ [<Max-Age> [<Expire-In>] ] [<Id>] [-- Cmd]
{
  test -n "$sd_log" || return 103
  local age_sec= expire_sec= cache_id= cache_file is=0

  while test $# -gt 0
    do
      test "$1" == "--" && break
      fnmatch "[@0-9]*" "$1" && {
        test -z "$age_sec" && age_sec=$1 || {
          test -z "$expire_sec" && expire_sec=$1 || return 64
        }
      } || {
        test -z "$cache_id" && cache_id=$1 || return 64
      }
      shift
    done
  test "$1" == "--" || return 64
  shift

  test -n "$cache_id" || cache_id=$(mkvid "$*" && echo "$vid")
  test -n "$age_sec" || age_sec=$STATUSDIR_EXPIRY_AGE
  test -n "$expire_sec" || expire_sec=$STATUSDIR_CLEAN_AGE

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

      contents )
          sd_file_update "$@"
          sd_file_contents || return
        ;;

      notify )
          # TODO: fork
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
