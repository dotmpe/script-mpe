#!/bin/bash


pd__edit()
{
  $EDITOR \
    $0 $(which projectdir-meta) \
    "$@"
}

# defer to python script for YAML parsing
pd_yml__meta=1
pd__meta()
{
  projectdir-meta "$@" || return $?
}

pd_yml__status=1
pd_bg__status=pd-clean.failed
# Run over known prefixes and present status indicators
pd__status()
{
  note "Getting status for checkouts"
  pd__list_prefixes "$1" | while read prefix
  do
    vc_check $prefix || continue
    pd__clean $prefix || touch $failed
  done
}

pd_yml__check=1
pd_bg__check=pd-check.failed
pd_today__check=pd-check.date
# Check with remote refs
pd__check()
{
  test -z "$2" || error "Surplus arguments" 1
  note "Checking prefixes"
  projectdir-meta -f $pd list-prefixes "$1" | while read prefix
  do
    vc_check $prefix || continue
    pd__sync $prefix || touch $failed
  done
}

pd__clean()
{
  test -e "$1/.git" || error "checkout dir expected" 1
  vc_clean "$1"
  case "$?" in
    0|"" )
      info "OK $(__vc_status "$1")"
    ;;
    1 )
      warn "Dirty: $(__vc_status "$1")"
      return 1
    ;;
    2 )
      note "Crufty: $(__vc_status "$1")"
      printf "$cruft\n" 1>&2
      return 2
    ;;
  esac
}

# drop clean checkouts and disable repository
pd__disable_clean()
{
  test -z "$2" || error "Surplus arguments" 1

  pwd=$(pwd)
  projectdir-meta -f $pd list-prefixes "$1" | while read prefix
  do
    test ! -d $prefix || {
      cd $pwd/$prefix
      git diff --quiet && {
        test -z "$(vc ufx)" && {
          warn "TODO remove $prefix if synced"
          # XXX need to fetch remotes, compare local branches
          #projectdir-meta -f $pd list-push-remotes $prefix | while read remote
          #do
          #  git push $remote --all
          #done
        }
      }
      cd $pwd
    }
  done
}

# add/remove repos, update remotes at first level. git only.
pd_yml__update=1
pd_bg__update='pd-.failed'
pd__update()
{
  test -z "$2" || error "Surplus arguments" 1

  backup_if_comments "$pd"

  projectdir-meta -f $pd list-prefixes "$1" | while read prefix
  do
    #match_grep_pattern_test "$prefix"
    test -d $prefix || {
      projectdir-meta -f $pd update-repo $prefix disable=true \
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

    grep -q '\<'$p_'\>\/\?\:' $pd && {

      info "Testing update $prefix props='$props'"
      projectdir-meta -f $pd update-repo $prefix \
        $props \
          && note "Updated metadata for $prefix" \
          || { r=$?; test $r -eq 42 && info "Metadata up-to-date for $prefix" \
            || warn "Error updating $prefix with '$props'"
          }

    } || {

      info "Testing add $prefix props='$props'"
      projectdir-meta -f $pd put-repo $prefix \
        $props \
          && note "Added metadata for $prefix" \
          || error "Unexpected error adding repo $?" $?
    }
  done
}

pd_yml__list_prefixes=1
pd__list_prefixes()
{
  test -z "$2" || error "surplus arguments" 1

  projectdir-meta -f $pd list-prefixes "$1" | while read prefix
  do
    match_grep_pattern_test "$prefix"
    grep -q "$p_" .gitignore || {
      echo $prefix >> .gitignore
    }
    echo $prefix
  done
}

# prepare Pd var
pd_yml__sync=1
# Want to track last (direct) run
pd_last__sync=1
# Update remotes and check refs
pd__sync()
{
  test -n "$1" || error "prefix argument expected" 1
  prefix=$1
  shift 1
  test -n "$1" || set -- $(vc_list_local_branches $prefix)
  pwd=$(pwd -P)

  (
    pd__meta -s list-upstream "$prefix" "$@" \
      || {
        warn "No sync setting, skipping $prefix"
        return 1
      }
  ) | while read remote branch
  do

    cd $pwd/$prefix

    test -d .git || error "Not a standalone .git: $prefix" 1

    test -e .git/FETCH_HEAD \
      && younger_than .git/FETCH_HEAD $GIT_AGE \
      || git fetch --quiet $remote

    local remoteref=$remote/$branch

    git show-ref --quiet $remoteref || {
      test -n "$choice_sync_push" && {
        git push $remote +$branch
      } || {
        error "Missing remote branch in $prefix: $remoteref"
        return 2
      }
    }

    local ahead=0 behind=0

    git diff --quiet ${remoteref}..${branch} \
      || ahead=$(git rev-list ${remoteref}..${branch} --count) \
    git diff --quiet ${branch}..${remoteref} \
      || behind=$(git rev-list ${branch}..${remoteref} --count)

    test $ahead -eq 0 -a $behind -eq 0 && {
      info "In sync: $prefix $remoteref"
      return
    }

    test $ahead -eq 0 || {
      note "$prefix ahead of $remoteref by $ahead commits"
    }

    test $behind -eq 0 || {
      # ignore upstream commits?
      test -n "$choice_sync_dismiss" \
        && return \
        || note "$prefix behind of $remoteref by $behind commits"
    }

    return 1
  done

  # XXX: look into git config for this: git for-each-ref --format="%(refname:short) %(upstream:short)" refs/heads

}

pd__enable()
{
  test -n "$1" || error "prefix argument expected" 1
  test -z "$2" || error "surplus arguments" 1
  pd=projects.yaml
  test -e "$pd"
  pd__meta -sq enabled $1 || pd__meta enable $1
  test -d $1 || {
    # TODO: get upstream and checkout to branch, iso. origin/master?
    uri=$(pd__meta get-uri $1 origin)
    test -n "$uri" || error "No uri for $1 origin" 1
    git clone $uri $1
  }
}

pd_yml__disable=1
pd__disable()
{
  test -n "$1" || error "prefix argument expected" 1
  test -n "$pd" || error "pd=$pd" 1

  pd__meta -q disabled $1 && {
    info "Already disabled: $1"

  } || {

    pd__meta disable $1 \
      && note "Disabled $1"
  }

  test ! -d $1 && {
    info "No checkout, nothing to do"
  } || {
    note "Found checkout, getting status.."

    choice_strict=1 \
      vc_clean $1 \
      || case "$?" in
          1 ) warn "Dirty: $(__vc_status "$1")" 1 ;;
          2 ) note "Crufty: $(__vc_status "$1")" 1 ;;
        esac

    choice_sync_dismiss=1 \
    pd__sync $1 \
      || error "Not in sync: $1" 1

    rm -rf $1 \
      && note "Removed checkout $1"
  }
}



pd_meta_bg_setup()
{
  test -n "$no_background" && {
    note "Forcing foreground/cleaning up background"
    test ! -e "/tmp/pd-serv.sock" || projectdir-meta exit \
      || error "Exiting old" $?
  } || {
    test ! -e "/tmp/pd-serv.sock" || error "pd meta bg already running" 1
    projectdir-meta --background &
    while test ! -e /tmp/pd-serv.sock
    do note "Waiting for server.." ; sleep 1 ; done
    info "Backgrounded pd-meta for $(pwd)/projects.yaml (PID $!)"
  }
}
pd_meta_bg_teardown()
{
  test -n "$no_background" || {
    projectdir-meta exit
    info "Closed background metadata server"
  }
}

vc_clean()
{
  dirty="$(cd $1; git diff --quiet || echo 1)"
  test -n "$dirty" && {
    return 1

  } || {

    test -n "$choice_strict" \
      && cruft="$(cd $1; vc excluded)" \
      || {

        projectdir-meta -q clean-mode $1 tracked || {

          projectdir-meta -q clean-mode $1 excluded \
            && cruft="$(cd $1; vc excluded)" \
            || cruft="$(cd $1; vc unversioned-files)"
        }

      }

    test -z "$cruft" || {
      return 2
    }
  }
}

vc_check()
{
  test -d "$1" && {
    projectdir-meta -sq enabled $1 || {
      note "To be disabled: $1"
    }
  } || {
    # skip check on missing dirs, note
    projectdir-meta -sq enabled $1 || return
    test -e $1 \
      && note "Not a checkout: $1" \
      || note "Missing checkout: $1"
    return 1
  }
}

vc_list_local_branches()
{
  local pwd=$(pwd)
  test -z "$1" || cd $1
  git branch -l | sed -E 's/\*|[[:space:]]//g'
  test -z "$1" || cd $pwd
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



pd__load()
{
  . ~/bin/os.lib.sh
  . ~/bin/date.lib.sh
  . ~/bin/match.sh "$@"
  . ~/bin/vc.sh "$@"

  test -z "$(try_value _yml__${subcmd})" || {
    pd=projects.yaml
    test -e "$pd" || error "No projects file $pd" 1
  }

  bg="$(try_value _bg__${subcmd})"
  test -z "$bg" || {
    pd_meta_bg_setup
    failed=$(statusdir.sh file $bg)
    test ! -e  $failed || rm $failed
  }

  export GIT_AGE=$_1HOUR

  today="$(try_value _today__${subcmd})"
  test -z "$today" || {
    today=$(statusdir.sh file $today)
    tdate=$(date +%y%m%d0000)
    test -n "$tdate" || error "formatting date" 1
    touch -t $tdate $today
  }

  case "$1" in
    * )
      ;;
  esac

  uname=$(uname)
}

pd__unload()
{
  test -n "$bg" && {
    pd_meta_bg_teardown
    test ! -e $failed || return 1
  }
  unset subcmd subcmd_pref \
          def_subcmd func_exists func
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

# ----


# Main

case "$0" in "" ) ;; "-*" ) ;; * )

  scriptname=projectdir
  test -n "$scriptalias" || scriptalias=pd

  base=$(basename $0 .sh)
  case "$base" in

    $scriptname | $scriptalias )

        # invoke with function name first argument,
        subcmd=$1 \
          subcmd_pref=${scriptalias} \
          def_subcmd=status \
          func_exists= \
          func=

        . ~/bin/main.sh
        . ~/bin/std.sh
        . ~/bin/projectdir.inc.sh "$@"

        try_subcmd && {
          shift 1
          pd__load $subcmd "$@" \
            && $func "$@" \
            && pd__unload \
            || exit $?
        }

     ;;

  esac

esac

