#!/bin/sh
# Created: 2015-12-14
lst__src="$_"

set -e



version=0.0.4-dev # script-mpe


# Script subcmd's funcs and vars

# See $scriptname help to get started

lst_man_1__names="List names for groups"
lst_spc__names="GROUP.."
lst_load__names=iI
lst__names()
{
  trueish "$choice_all" && {
    ignores_groups "$@"
  } || {
    ignores_groups_exist "$@"
  }
}

lst_man_1__globs="List globs (in group)"
lst_als__list=globs
lst_spc__globs="[GROUP]"
lst_load__globs=iI
lst__globs()
{
  local ext=
  test -z "$1" || ext=.$1
  lst_init_ignores "$ext" local global
  read_nix_style_file $IGNORE_GLOBFILE$ext
}

lst_man_1__local="List globs from local file only, without inherited patterns"
lst_load__local=iI
lst__local()
{
  local ext=
  test -z "$1" || ext=.$1
  mv $IGNORE_GLOBFILE$ext $IGNORE_GLOBFILE.bup$ext
  lst_init_ignores "$ext.tmp" local global
  mv $IGNORE_GLOBFILE.bup$ext $IGNORE_GLOBFILE$ext
  diff $IGNORE_GLOBFILE$ext $IGNORE_GLOBFILE$ext.tmp ||
    note "Local lines shown above"
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


lst_man_1__version="Version info"
lst__version()
{
  echo "$(cat $scriptpath/.app-id)/$version"
}
lst_als__V=version


lst__edit()
{
  $EDITOR \
    $0 \
    $scriptpath/list*sh \
    "$@"
}
lst_als___e=edit




# Script main functions

lst_main()
{
  local \
      scriptname=list \
      scriptalias=lst \
      base=$(basename $0 .sh) \
      scriptpath="$(cd "$(dirname "$0")"; pwd -P)" \
      failed=

  test -n "$verbosity" || verbosity=5

  export SCRIPTPATH=$scriptpath
  . $scriptpath/util.sh
  util_init

  lst_init || exit $?

  case "$base" in

    $scriptname | $scriptalias )

        test -n "$1" || set -- list

        lst_lib || exit $?
        run_subcmd "$@" || exit $?
      ;;

    * )
        error "not a frontend for $base ($scriptname)" 1
      ;;

  esac
}

# FIXME: Pre-bootstrap init
lst_init()
{
  test -n "$scriptpath"
  . $scriptpath/box.init.sh
  lib_load box main
  box_run_sh_test
  # -- lst box init sentinel --
}

# FIXME: 2nd boostrap init
lst_lib()
{
  local __load_lib=1
  lib_load meta list
  lst_preload || exit $?
  lib_load ignores date
  # -- lst box lib sentinel --
  set --
}


# Main entry - bootstrap script if requested
# Use hyphen to ignore source exec in login shell
case "$0" in "" ) ;; "-"* ) ;; * )
  # Ignore 'load-ext' sub-command
  test -z "$__load_lib" || set -- "load-ext"
  case "$1" in load-ext ) ;; * )
      lst_main "$@"
    ;;
  esac ;;
esac

