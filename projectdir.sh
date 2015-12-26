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
      test -n "$dirty" && {
        warn "Dirty: $(__vc_status "$prefix")"

      } || {

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
      }
  done
}

# TODO: more terse status overview
pd__check()
{
  test -n "$1" || set -- "projects.yaml" "$2"
  test -e "$1" || error "No projects file $1" 1
  test -z "$3" || error "Surplus arguments" 1

}

pd__dirty()
{
  test -n "$1" || set -- "projects.yaml" "$2"
  test -e "$1" || error "No projects file $1" 1
  test -z "$3" || error "Surplus arguments" 1

  pwd=$(pwd)
  projectdir-meta -f $1 list-prefixes "$2" | while read prefix
  do
    test ! -d $prefix || {
      cd $pwd/$prefix
      test -z "$(vc ufx)" || {
        warn "Dirty: $prefix"
      }
      cd $pwd
    }
  done
}

# drop clean checkouts and disable repository
pd__disable_clean()
{
  test -n "$1" || set -- "projects.yaml" "$2"
  test -e "$1" || error "No projects file $1" 1
  test -z "$3" || error "Surplus arguments" 1

  pwd=$(pwd)
  projectdir-meta -f $1 list-prefixes "$2" | while read prefix
  do
    test ! -d $prefix || {
      cd $pwd/$prefix
      test -z "$(vc ufx)" && {
        warn "TODO remove $prefix if synced"
      }
      cd $pwd
    }
  done
}

# add/remove repos, update remotes at first level. git only.
pd__update()
{
  test -n "$1" || set -- "projects.yaml" "$2"
  test -e "$1" || error "No projects file $1" 1
  test -z "$3" || error "Surplus arguments" 1

  backup_if_comments "$1"


  projectdir-meta -f $1 list-prefixes "$2" | while read prefix
  do
    #match_grep_pattern_test "$prefix"
    test -d $prefix || {
      projectdir-meta -f $1 update-repo $prefix disable=true \
        && note "Disabled $prefix"\
        || {
          r=$?; test $r -eq 42 && info "Checkout at $prefix already disabled" \
          || warn "Error disabling $prefix"
        }
    }
  done


  for git in */.git
  do
    prefix=$(dirname $git)
    props="$(verbosity=0;cd $prefix;echo "$(vc remotes sh)")"

    match_grep_pattern_test "$prefix"

    grep -q '\<'$p_'\>\/\?\:' $1 && {

      info "Testing update $prefix props='$props'"
      projectdir-meta -f $1 update-repo $prefix \
        $props \
          && note "Updated metadata for $prefix" \
          || { r=$?; test $r -eq 42 && info "Metadata up-to-date for $prefix" \
            || warn "Error updating $prefix with '$props'"
          }

    } || {

      info "Testing add $prefix props='$props'"
      projectdir-meta -f $1 add-repo $prefix \
        $props \
          && note "Added metadata for $prefix" \
          || error "Unexpected error adding repo $?" $?
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



backup_if_comments()
{
  test -f "$1" || error "file expected: '$1'" 1
  grep -q '^\s*#' $1 && {
    test ! -e $1.comments || error "backup exists: '$1.comments'" 1
    cp $1 $1.comments
  } || noop

}


# ----


def_func=pd__status


pd__load()
{
  printf ""
}

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
			pd__load
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

