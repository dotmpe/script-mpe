#!/usr/bin/env bash
export UC_LOG_BASE=fswatch.sh[$$]
sh_mode dev strict

gdate=date
lib_require str date-htd os-htd argv str-uc

note () { $LOG notice : "$1" "${2:+E}$2" ${2:-0}; }
error () { $LOG error : "$1" "E$2" ${2:?}; }
warn () { $LOG warn : "$1" "${2:+E}$2" ${2:-0}; }
TODO () { error "$*" 123 || exit $?; }

reseed () # Reload env
{
  local seed
  for seed in "${@:?}"
  do . "$seed" ||
    error "Failed loading seed scriptfile" $? || exit $?
  done
}

$LOG notice :start "Processing invocation" "($#) $*"

#declare -g WB_SEED
declare -a preload

# XXX: example uc-profile value
#: "${WB_SEED:={.{local,package}.sh,{.,\}env.sh\}}"
case "${1:?}" in
  --seed ) WB_SEED=${2:?}
      shift 2
    ;;
esac
for seed in $(str_sh_expand_braces "${WB_SEED:-{,.\}env.sh}")
do
  test -e "$seed" || continue
  preload+=( "$seed" )
done
reseed "${preload[@]}"

declare last_run

assert_basedirs "${last_run:=.meta/run/fswatch-$$.last-run}"
case "${1:-}" in
  --clean )
      rm -v "$(dirname "${last_run:?}")/"fswatch-*.last-run
      shift
    ;;
esac
test ! -e "$last_run" || error "This shouldn't happen" 3

declare script

case "${1:?}" in
  --script ) script=${2:?}
      shift 2
    ;;
esac

case "${1:?}" in
  --reload )
      preload+=( "$script" )
      shift
    ;;
esac

: "${delay:=0.1}"
: "${rest:=30}"

$LOG notice :start "Booting script" "delay=$delay rest=$rest script=$script"

declare -a files cmd opts
declare restart

case "${1:?}" in
  --restart ) restart=true
      opts+=( "--one-event" )
      shift
    ;;
esac

declare excludes
case "${1:?}" in
  --exclude )
      excludes=${2:?}
      shift 2
    ;;
esac

declare attributes
case "${1:?}" in
  --attributes )
      attributes=true
      shift
    ;;
esac

argv_is_seq "$@" && {
  shift &&

  argv_arr_seq files "$@"
  shift $argc

  argv_arr_seq cmd "$@"
  shift $argc

  test 0 -eq $# || shift

} || {

  "${attributes:-false}" && {
    TODO use defaults for file/cmd set from attributes file

  } || {
    argv_arr_seq files "$@" &&
    shift $argc
    cmd+=( "${1:?}" )
  }
  shift
}

"${attributes:-false}" && {
  TODO process files, cmd and excludes param using attributes file
}

$LOG info : "Watching ${#files[*]} files, building fswatch options "

opts+=(
  #--one-event            # exit fswatch after each event
  "-E"                    # Use extended regex
  "--event-flags"         # Suffix path w. event type, etc?
  "--timestamp"           # Prefix path w. time
  #--utc-time             # Universal iso. local time
  "--format-time"         # Format for timestamp
    "${DT_ISO_FULL:?}"
  "--latency"             # Startup delay for command after trigger event
    "${delay:?}"
)

test -n "${excludes-}" && {
  # TODO: write/source glob filter
  if_ok "$(< "$_" glob_to_ereg)" &&
  mapfile -t exclude_re <<< "$_" ||
    error "Reading excludes from file <E$?:$excludes>" $?
} ||
  exclude_re=(
    '\.?tags(\.te?mp)?'
    '\.git'
    '\.svn'
    '\.bzr'
    '\.sw[a-p,x]$'
    '.*\~$'
  )

for regex in "${exclude_re[@]}"
do
  opts+=( --exclude "$regex" )
done


while true
do
  # Reload here for restarting fswatch sessions
  { "${restart:-false}" && ! "${reload:-false}" || "${exited:-false}"
  } && {
    info "Reload: re-seeding after restart"
    reseed "${preload[@]}"
  }

  "${exited:-false}" &&
    note "Restarting fswatch, waiting for events" ||
    note "Starting fswatch, waiting for events"
  fswatch \
    "${opts[@]}" \
    "${files[@]}" \
        | while read -r dt file flags
    do
      test -n "$dt" || error "no fswatch event, aborted" 1 || return

      case " $flags " in
        ( *" Updated "* ) ;;
        * ) continue ;
      esac

      # Reload here for long-running fswatch sessions
      ! "${restart:-false}" && "${reload:-false}" && {
        info "Reload: reseed during read-loop"
        reseed "${preload[@]}"
      }

      { test ! -e "$last_run" || older_than "$last_run" "$rest"
      } && {
        note "Triggered at $(date +%H:%M) by $file"
        WATCH_FILE=$file WATCH_DT=$dt WATCH_FLAGS=$flags \
          "${cmd[@]}" || warn "Command failed"
        touch $last_run
      } || {
        wait_more=$(( rest - ( $(date +%s) - $(filemtime $last_run) ) ))
        note "Ignored $file; Last run less than $rest seconds ago ($wait_more)"
        continue
      }
      note "Done at $(date +%H:%M), watching for next change"
    done || error "error" $? || {
      test 130 -eq $? && break
    }
  exited=true

done
sh_noerr stderr rm $last_run

#
