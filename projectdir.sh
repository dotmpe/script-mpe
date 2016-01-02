#!/bin/bash

. ~/bin/std.sh
. ~/bin/projectdir.inc.sh "$@"
. ~/bin/vc.sh "$@"

scriptname=projectdir
test -n "$scriptalias" || scriptalias=pd

# ----



pd__edit()
{
  $EDITOR \
    $0 $(which projectdir-meta) \
    "$@"
}

# defer to python script for YAML parsing
pd__meta()
{
  projectdir-meta "$@" || return $?
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

# Run over known prefixes and present status indicators
pd__status()
{
  note "Getting status for checkouts"
  pd_meta_bg_setup
  pd__list_prefixes | while read prefix
  do
    vc_check $prefix || continue
    pd__clean $prefix
  done
  pd_meta_bg_teardown
}

# Check with remote refs
pd__check()
{
  test -n "$1" || set -- "projects.yaml" "$2"
  test -e "$1" || error "No projects file $1" 1
  test -z "$3" || error "Surplus arguments" 1

  pd_meta_bg_setup
  failed=$(statusdir.sh file pd-check.failed)
  test ! -e  $failed || rm $failed

  note "Checking prefixes"
  projectdir-meta -f $1 list-prefixes "$2" | while read prefix
  do
    vc_check $prefix || continue
    pd__sync $prefix || touch $failed
  done

  pd_meta_bg_teardown
  test ! -e $failed || return 1
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
    ;;
    2 )
      note "Crufty: $(__vc_status "$1")"
      printf "$cruft\n" 1>&2
    ;;
  esac
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
      git diff --quiet && {
        test -z "$(vc ufx)" && {
          warn "TODO remove $prefix if synced"
          # XXX need to fetch remotes, compare local branches
          #projectdir-meta -f $1 list-push-remotes $prefix | while read remote
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
pd__update()
{
  test -n "$1" || set -- "projects.yaml" "$2"
  test -e "$1" || error "No projects file $1" 1
  test -z "$3" || error "Surplus arguments" 1

  backup_if_comments "$1"

  pd_meta_bg_setup

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
      projectdir-meta -f $1 put-repo $prefix \
        $props \
          && note "Added metadata for $prefix" \
          || error "Unexpected error adding repo $?" $?
    }
  done

  pd_meta_bg_teardown
}

pd__list_prefixes()
{
  test -n "$1" || set -- "projects.yaml" "$2"
  test -e "$1" || error "No projects file $1" 1
  #test -z "$2" || { test -d "$2" || error "Argument must be root-dir" 1; }
  test -z "$3" || error "surplus arguments" 1

  projectdir-meta -f $1 list-prefixes "$2" | while read prefix
  do
    match_grep_pattern_test "$prefix"
    grep -q "$p_" .gitignore || {
      echo $prefix >> .gitignore
    }
    echo $prefix
  done
}

vc_list_local_branches()
{
  local pwd=$(pwd)
  test -z "$1" || cd $1
  git branch -l | sed -E 's/\*|[[:space:]]//g'
  test -z "$1" || cd $pwd
}

pd__sync()
{
  test -n "$1" || error "prefix argument expected" 1
  prefix=$1
  shift 1

  pd=projects.yaml
  test -e "$pd"

  pwd=$(pwd)

  test -n "$1" || set -- $(vc_list_local_branches $prefix)

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

pd__disable()
{
  test -n "$1" || error "prefix argument expected" 1

  pd=projects.yaml
  test -e "$pd"

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
  . ~/bin/os.lib.sh
  . ~/bin/date.lib.sh
  . ~/bin/match.sh "$@"
  export GIT_AGE=$_1HOUR
  uname=$(uname)
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

# ----


# Main
case "$0" in "" ) ;; "-*" ) ;; * )

  base=$(basename $0 .sh)
  case "$base" in

    $scriptname | $scriptalias )

        # invoke with function name first argument,
        cmd=$1
        [ -n "$def_func" -a -z "$cmd" ] \
          && func=$def_func \
          || func=$(echo pd__$cmd | tr '-' '_')

        type $func &>/dev/null && {
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

      ;;

#    * )
#      echo "Not a frontend for $base ($scriptname)"
#      ;;

  esac

esac

