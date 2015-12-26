#!/bin/bash

. ~/bin/std.sh
. ~/bin/match.sh "$@"
. ~/bin/vc.sh "$@"
. ~/bin/projectdir.inc.sh "$@"


scriptname=projectdir

# ----




pd__edit()
{
  $EDITOR $0 "$@"
}

pd__status()
{
  note "Checking prefixes"
  pd__list_prefixes | while read prefix
  do
      test -d "$prefix" && {
          projectdir-meta -sq enabled $prefix || {
            note "To be disabled: $prefix"
          }
      } || {
          # skip check on missing dirs, note
          projectdir-meta -sq enabled $prefix || continue
          test -e $prefix \
              && note "Not a checkout: $prefix" \
              || note "Missing checkout: $prefix"
          continue
      }

      dirty="$(cd $prefix; git diff --quiet || echo 1)"
      test -z "$dirty" && {

        test -n "$choice_strict" \
          && cruft="$(cd $prefix; vc excluded)" \
          || {

            projectdir-meta -q clean-mode $prefix tracked || {

              projectdir-meta -q clean-mode $prefix excluded \
                && cruft="$(cd $prefix; vc excluded)" \
                || cruft="$(cd $prefix; vc unversioned-files)"
            }

          }

        test -z "$cruft" && {
          info "OK $(__vc_status "$prefix")"

        } || {
          note "Crufty: $(__vc_status "$prefix")"
          printf "$cruft\n" 1>&2
        }
      } || {
        warn "Dirty: $(__vc_status "$prefix")"
      }
  done
}

pd__list_prefixes()
{
  test -n "$1" || set -- "projects.yaml" "$2"
  test -e "$1" || error "No projects file $1" 1
  #test -z "$2" || { test -d "$2" || error "Argument must be root-dir" 1; }
  test -z "$3" || error "Surplus arguments" 1

  projectdir-meta -f $1 list-prefixes "$2" | while read prefix
  do
    match_grep_pattern_test "$prefix"
    grep -q "$p_" .gitignore || {
      echo $prefix >> .gitignore
    }
    echo $prefix
  done
}

pd__check()
{
  echo TODO find new repos
}


# ----


def_func=pd__status


pd__usage()
{
	echo 'Usage: '
	echo "  $scriptname.sh <cmd> [<args>..]"
}

pd__help()
{
	pd__usage
	echo 'Functions: '
	echo '  status                           List abbreviated status strings for all repos'
	echo ''
	echo '  help                             print this help listing.'
}


# Main
if [ -n "$0" ] && [ $0 != "-bash" ]; then
	# Do something if script invoked as 'project'
	if [ "$(basename $0 .sh)" = "projectdir" ]; then

		cmd=$1
		func=$cmd
		[ -n "$def_func" -a -z "$func" ] \
			&& func=$def_func \
			|| func=$(echo "pd__$cmd" | tr '-' '_')
		type $func &> /dev/null && {
			func_exists=1
			shift 1
			$func "$@"
		} || {
			e=$?
			[ -z "$cmd" ] && {
				pd__usage
				error 'No command given, see "help"' 1
			} || {
				[ "$e" = "1" -a -z "$func_exists" ] && {
					pd__usage
					error "No such command: $cmd" 1
				} || {
					error "Command $cmd returned $e" $e
				}
			}
		}
	fi
fi

