#!/bin/sh
# Created: 2015-12-14
lst_src="$_"

set -e

version=0.0.2-dev # script-mpe


lst_man_1__version="Version info"
lst__version()
{
  echo "$(cat $scriptdir/.app-id)/$version"
}
lst_als__V=version


lst__edit()
{
  $EDITOR \
    $0 \
    $scriptdir/list*sh \
    "$@"
}
lst_als___e=edit


lst_load__list=iI
lst__list()
{
  ls -la
  failed "TODO"
}

lst_load__excludes=iI
lst__excludes()
{
  echo
}

lst_man_1__watch="Watch files for changes"
lst_spc__watch="FILE|DIR [GLOB [[CMD]]"
lst_load__watch=iI
lst__watch()
{
  test -n "$lst_watch_be" || error "'watch' backend required" 1
  req_path_arg "$@" || return $?
  test -n "$2" || set -- "$1" "*" "$3"

  # FIXME: write this into load phase
  lst__watch_${lst_watch_be} "$@" \
    || return $?
}

lst_spc__watch_fswatch="FILE|DIR [GLOB [CMD]]"
lst_load__watch_fswatch=iI
lst__watch_fswatch()
{
  req_path_arg "$@" || return $?
  test -n "$2" || set -- "$1" "*" "$3"
  test -n "$3" || set -- "$1" "$2" "echo "
  test -n "$delay" || delay=0.1
  test -n "$rest" || rest=30
  local last_run=$(setup_tmpf .last-run)
  test ! -e $last_run || rm $last_run
  touch_ts $(( $(date +%s) - $rest )) $last_run
  note "delay=$delay rest=$rest"
  while true
  do
    fswatch $1 -E \
      --one-event \
      --event-flags \
      --timestamp \
      --utc-time \
      --format-time $archive_dt_strf \
      --latency $delay \
      --exclude '\.build' \
      --exclude 'build' \
      --exclude '\.git' \
      --exclude '\.svn' \
      --exclude '.*\/[0-9]+$' \
      --exclude '\.bzr' \
      --exclude '\.sw[a-p]$' \
      --exclude '.*\~$' | while read dt file flags
      do
        test -n "$dt" || error "no fswatch event, aborted" 1
        older_than $last_run $rest && {
          note "Triggered at $(date +%H:%M) by $file"
          $3 || warn "Command failed"
          touch $last_run
        } || {
          wait_more=$(( $rest - ( $(date +%s) - $(filemtime $last_run) ) ))
          note "Ignored $file; Last run less than $rest seconds ago ($wait_more)"
          continue
        }
        note "Done at $(date +%H:%M), watching for next change"
      done || error "error" $?
  done
  rm $last_run
}

lst_spc__watch_inotify="FILE|DIR [GLOB [CMD]]"
lst_load__watch_inotify=iI
lst__watch_inotify()
{
  req_path_arg "$@" || return $?
  test -n "$2" || set -- "$1" "*" "$3"
	test -d "$1" && {
	  local events=close_write,moved_to,create
	  test -z "$4" || error "surplus arguments" 1
    test -n "$3" || set -- "$1" "*" \
      'echo directory="$directory" events="$events" filename="$filename"'
		inotifywait -e $events $1 |
			while read -r directory events filename; do
        fnmatch "$3" "$filename" && {
          $4
        }
			done
	} || {
	  test -z "$3" || error "surplus arguments" 1
    test -n "$2" || set -- "$1"
      'echo directory="$directory" events="$events" filename="$filename"'
	  local events=close_write
		while inotifywait -e $events $1; do
		  $2
		done
	}
}


# List all paths; -dfl or with --tasks filters
lst_load__list_paths=iO
lst__list_paths()
{
  opt_args "$@"
  set -- "$(cat $arguments)"
  req_cdir_arg "$@"
  shift 1; test -z "$@" || error surplus-arguments 1
  local find_ignores="$(find_ignores $IGNORE_GLOBFILE) $(lst__list_paths_opts)"
  # FIXME: some nice way to get these added in certain contexts
  find_ignores="-path \"*/.git\" -prune $find_ignores "
  find_ignores="-path \"*/.bzr\" -prune -o $find_ignores "
  find_ignores="-path \"*/.svn\" -prune -o $find_ignores "
  debug "Find ignores: $find_ignores"
  eval find $path $find_ignores -o -path . -o -print
}
lst__list_paths_opts()
{
  while read option; do case "$option" in
      -d ) echo "-o -not -type d " ;;
      -f ) echo "-o -not -type f " ;;
      -l ) echo "-o -not -type l " ;;
      --tasks )
          for tag in no-tasks shadow-tasks
          do
            meta_attribute tagged $tag | while read glob
            do
              glob_to_find_prune "$glob"
            done
          done
          echo " -o -not -type f "
        ;;
      --add-scm-ext )
          find_ignores="-path \"*/.git\" -prune $find_ignores "
          find_ignores="-path \"*/.bzr\" -prune -o $find_ignores "
          find_ignores="-path \"*/.svn\" -prune -o $find_ignores "
        ;;
      * ) echo "$option " ;;
    esac
  done < $options
}




### Main


lst_main()
{
  local scriptname=lst base=$(basename $0 .sh) \
    scriptdir="$(cd "$(dirname "$0")"; pwd -P)" \
    failed=

  test -n "$verbosity" || verbosity=5

  export SCRIPTPATH=$scriptdir
  . $scriptdir/util.sh
  util_init

  lst_init || exit $?

  case "$base" in

    $scriptname )

        test -n "$1" || set -- list

        lst_lib || exit $?
        run_subcmd "$@" || exit $?
      ;;

    * )
        error "not a frontend for $base ($scriptname)" 1
      ;;

  esac
}

lst_init()
{
  test -n "$scriptdir"
  lib_load box main
  . $scriptdir/box.init.sh
  box_run_sh_test
  . $scriptdir/main.init.sh
  # -- lst box init sentinel --
}

lst_lib()
{
  local __load_lib=1
  lib_load meta list ignores date
  # -- lst box lib sentinel --
  set --
}

# Use hyphen to ignore source exec in login shell
case "$0" in "" ) ;; "-"* ) ;; * )
  # Ignore 'load-ext' sub-command
  test -z "$__load_lib" || set -- "load-ext"
  case "$1" in load-ext ) ;; * )
    lst_main "$@"
  ;; esac
;; esac


