#!/bin/sh
pd__source=$_


pd__edit()
{
  $EDITOR \
    $0 $(which projectdir-meta) \
    "$@"
}

pd_run__meta=y
# Defer to python script for YAML parsing
pd__meta()
{
  projectdir-meta -f $pd "$@" || return $?
}

pd_run__status=ybf
# Run over known prefixes and present status indicators
pd__status()
{
  test -z "$2" || error "Surplus arguments: $2" 1
  note "Getting status for checkouts"
  pd__list_prefixes "$1" | while read prefix
  do
    vc_check $prefix || continue
    pd__clean $prefix || touch $failed
  done
}

pd_run__check=ybf
# Check with remote refs
pd__check()
{
  test -z "$2" || error "Surplus arguments: $2" 1
  note "Checking prefixes"
  pd__meta list-prefixes "$1" | while read prefix
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
  test -z "$2" || error "Surplus arguments: $2" 1
  pwd=$(pwd)
  pd__meta list-prefixes "$1" | while read prefix
  do
    test ! -d $prefix || {
      cd $pwd/$prefix
      git diff --quiet && {
        test -z "$(vc ufx)" && {
          warn "TODO remove $prefix if synced"
          # XXX need to fetch remotes, compare local branches
          #pd__meta list-push-remotes $prefix | while read remote
          #do
          #  git push $remote --all
          #done
        }
      }
      cd $pwd
    }
  done
}

# Add/remove repos, update remotes at first level. git only.
pd_run__update=yfb
pd__update()
{
  test -z "$2" || error "Surplus arguments: $2" 1

  backup_if_comments "$pd"

  pd__meta list-enabled "$1" | while read prefix
  do
    test -d $prefix || {
      pd__meta update-repo $prefix disabled=true \
        && note "Disabled $prefix" \
        || touch $failed
    }
  done

  for git in */.git
  do
    prefix=$(dirname $git)
    match_grep_pattern_test "$prefix"

    #{ cd $prefix; git remotes; } | while read remote
    #do
    #  echo
    #done

    props="$(verbosity=0;cd $prefix;echo "$(vc remotes sh)")"
    test -n "$props" || {
      error "No remotes for $prefix"
      touch $failed
    }

    pd__meta -q get-repo $prefix && {
      pd__meta update-repo $prefix $props \
        && note "Updated metadata for $prefix" \
        || { r=$?; test $r -eq 42 && info "Metadata up-to-date for $prefix" \
          || { warn "Error updating $prefix with '$props'"
            touch $failed
          } }
    } || {

      info "Testing add $prefix props='$props'"
      pd__meta put-repo $prefix $props \
        && note "Added metadata for $prefix" \
        || error "Unexpected error adding repo $?" $?
    }
  done
}

pd_run__list_prefixes=y
pd__list_prefixes()
{
  test -z "$2" || error "Surplus arguments: $2" 1
  pd__meta list-prefixes "$1" | while read prefix
  do
    match_grep_pattern_test "$prefix"
    grep -q "$p_" .gitignore || {
      echo $prefix >> .gitignore
    }
    echo $prefix
  done
}

# prepare Pd var
pd_run__sync=y
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
      && younger_than .git/FETCH_HEAD $PD_SYNC_AGE \
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

pd_run__enable=y
pd__enable()
{
  test -n "$1" || error "prefix argument expected" 1
  test -z "$2" || error "Surplus arguments: $2" 1

  pd__meta -sq enabled $1 || pd__meta enable $1
  test -d $1 || {
    # TODO: get upstream and checkout to branch, iso. origin/master?
    uri=$(pd__meta get-uri $1 origin)
    test -n "$uri" || error "No uri for $1 origin" 1
    git clone $uri $1
  }
}

pd_run__disable=y
pd__disable()
{
  test -n "$1" || error "prefix argument expected" 1
  test -z "$2" || error "Surplus arguments: $2" 1

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



# ----


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

pd__load()
{
  for x in $(try_value "${subcmd}" "" run | sed 's/./&\ /g')
  do case "$x" in

      y )
        # set/check for Pd for subcmd
        pd=projects.yaml
        test -e "$pd" || error "No projects file $pd" 1
        ;;

      f )
        failed=${base}-$subcmd.failed
        ;;

      b )
        # run metadata server in background for subcmd
        pd_meta_bg_setup
        ;;

    esac
  done

  export PD_SYNC_AGE=$_3HOUR

  local tdy="$(try_value "${subcmd}" "" today)"
  test -z "$tdy" || {
    today=$(statusdir.sh file $tdy)
    tdate=$(date +%y%m%d0000)
    test -n "$tdate" || error "formatting date" 1
    touch -t $tdate $today
  }

  uname=$(uname)
}

pd__unload()
{
  unset subcmd subcmd_pref \
          def_subcmd func_exists func
  test ! -e "/tmp/pd-serv.sock" || {
    pd_meta_bg_teardown
    unset bgd
  }
  test -z "$failed" -o ! -e "$failed" || {
    rm $failed
    unset failed
    return 1
  }
}

pd__init()
{
  . ~/bin/main.sh
  . ~/bin/std.sh
  . ~/bin/projectdir.inc.sh "$@"
  . ~/bin/os.lib.sh
  . ~/bin/date.lib.sh
  . ~/bin/match.sh load-ext
  set -x
  . ~/bin/vc.sh load-ext
  # -- pd box init sentinel --
}

pd__lib()
{
  . ~/bin/util.sh
  . ~/bin/box.lib.sh
  # -- pd box lib sentinel --
}


### Main

pd__main()
{
  local scriptname=projectdir scriptalias=pd base=$(basename $pd__source .sh) \
    subcmd=$1

  case "$base" in

    $scriptname | $scriptalias )

        # invoke with function name first argument,
        local scsep=__ \
          subcmd_pref=${scriptalias} \
          def_subcmd=status \
          func_exists= \
          func=

        pd__init
        try_subcmd && {
          pd__lib
          box_init pd
          shift 1
          pd__load $subcmd "$@" \
            && $func "$@" \
            && pd__unload \
            || exit $?
        }

      ;;

    * )
      echo "Not a frontend for $base ($scriptname)"
      exit 1
      ;;

  esac
}

case "$0" in "" ) ;; "-*" ) ;; * )

  # XXX working on Darwin 10.8.5, not Linux..
  case "$1" in load-ext ) ;; * )

      pd__main "$@"
    ;;

  esac ;;
esac

