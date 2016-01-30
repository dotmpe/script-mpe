#!/bin/sh
# Created: 2015-12-14
pd__source=$_


pd__edit()
{
  $EDITOR \
    $0 \
    ~/bin/projectdir.inc.sh \
    $(which projectdir-meta) \
    "$@"
}

pd_run__meta=y
# Defer to python script for YAML parsing
pd__meta()
{
  test -n "$1" || set -- --background
  projectdir-meta -f $pd --address $sock "$@" || return $?
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
    test -d "$prefix" || continue
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
    test -d "$prefix" || continue
    pd sync $prefix || touch $failed
  done
}

pd__clean()
{
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
      warn "Crufty: $(__vc_status "$1")"
      test $verbosity -gt 6 &&
        printf "$cruft\n" 1>&2 || noop
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
  test -n "$1" || set -- "*"

  backup_if_comments "$pd"

  while test ${#@} -gt 0
  do

    test -d "$1" -a -e "$1/.git" || {
      info "Skipped non-checkout path $1"
      shift
      continue
    }

    pd__meta list-enabled "$1" | while read prefix
    do
      test -d $prefix || {
        pd__meta -s enabled $prefix \
          && continue \
          || {

          pd__meta update-repo $prefix disabled=true \
            && note "Disabled $prefix" \
            || touch $failed
        }
      }
    done

    for git in $1/.git
    do
      prefix=$(dirname $git)
      match_grep_pattern_test "$prefix"

      #{ cd $prefix; git remotes; } | while read remote
      #do
      #  echo
      #done

      props=
      test -d $prefix/.git/annex && {
        props="annex=true"
      }

      props="$props $(verbosity=0;cd $prefix;echo "$(vc remotes sh)")"
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

    shift
  done
}

pd_run__find=y
pd_spc_find='[<path>|<localname> [<project>]]'
pd__find()
{
  test -z "$3" || error "Surplus arguments: $3" 1
  test -n "$2" && {
    fnmatch "*/*" "$1" && {
      pd__meta list-prefixes "$1"
    } || {
      pd__meta list-local -g "$2" "*$1*"
    }
  } || {
    pd__meta list-prefixes -g "*$1*"
  }
}

pd_run__list_prefixes=y
pd__list_prefixes()
{
  test -z "$2" || error "Surplus arguments: $2" 1
  pd__meta list-prefixes "$1"
}

pd_run__compile_ignores=y
pd__compile_ignores()
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
pd_run__sync=yf
# Update remotes and check refs
pd__sync()
{
  test -n "$1" || error "prefix argument expected" 1
  prefix=$1

  shift 1
  test -n "$1" || set -- $(vc_list_local_branches $prefix)
  pwd=$(pwd -P)

  cd $pwd/$prefix

  test -d .git || error "Not a standalone .git: $prefix" 1

  test -e .git/FETCH_HEAD && younger_than .git/FETCH_HEAD $PD_SYNC_AGE && {
    return
  }

  test ! -d .git/annex || {
    git annex sync
    return $?
  }

  cd $pwd

  (
    pd__meta -s list-upstream "$prefix" "$@" \
      || {
        warn "No sync setting, skipping $prefix"
        return 1
      }
  ) | while read remote branch
  do
    fnmatch "*annex*" $branch && continue || noop

    cd $pwd/$prefix

    git fetch --quiet $remote || {
      error "fetching $remote"
      touch $failed
      continue
    }

    local remoteref=$remote/$branch

    git show-ref --quiet $remoteref || {
      test -n "$choice_sync_push" && {
        git push $remote +$branch
      } || {
        error "Missing remote branch in $prefix: $remoteref"
        touch $failed
        continue
      }
    }

    local ahead=0 behind=0

    git diff --quiet ${remoteref}..${branch} \
      || ahead=$(git rev-list ${remoteref}..${branch} --count) \

    git diff --quiet ${branch}..${remoteref} \
      || behind=$(git rev-list ${branch}..${remoteref} --count)

    test $ahead -eq 0 -a $behind -eq 0 && {
      info "In sync: $prefix $remoteref"
      continue
    }

    test $ahead -eq 0 || {
      note "$prefix ahead of $remote#$branch by $ahead commits"
      test -n "$dry_run" \
        || git push $remote $branch \
        || touch $failed
    }

    test $behind -eq 0 || {
      # ignore upstream commits?
      test -n "$choice_sync_dismiss" \
        || {
          note "$prefix behind of $remote#$branch by $behind commits"
          test -n "$dry_run" || touch $failed
        }
    }

  done

  # XXX: look into git config for this: git for-each-ref --format="%(refname:short) %(upstream:short)" refs/heads
}

# Assert checkout exists, or reinitialize from Pd document.
pd_run__enable=y
pd__enable()
{
  test -n "$1" || error "prefix argument expected" 1
  test -z "$2" || error "Surplus arguments: $2" 1
  pd__meta -q get-repo $1 || error "No repo for $1" 1
  pd__meta -sq enabled $1 || pd__meta enable $1
  test -d $1 || {
    upstream="$(pd__meta list-upstream "$1" | sed 's/^\([^\ ]*\).*$/\1/g' | head -n 1)"
    test -n "$upstream" || upstream=origin
    uri="$(pd__meta get-uri "$1" $upstream)"
    test -n "$uri" || error "No uri for $1 $upstream" 1
    git clone $uri --origin $upstream $1 || error "Cloning $uri" 1
    pd__init $1
  }
}

pd_run__init=y
pd__init()
{
  test -n "$1" || error "prefix argument expected" 1
  test -z "$2" || error "Surplus arguments: $2" 1

  cwd=$(pwd)
  pd__meta list-remotes "$1" | while read remote
  do
    cd "$cwd"
    url=$(pd__meta get-uri "$1" $remote)
    cd "$cwd/$1"
    git config remote.$remote.url >/dev/null && {
      test "$(git config remote.$remote.url)" = "$url" || {
        no_act \
          && echo "git remote add $remote $url ( ** DRY RUN ** )" \
          || git remote set-url $remote $url
      }
    } || {
      no_act \
        && echo "git remote add $remote $url ( ** DRY RUN ** )" \
        || git remote add $remote $url
    }
  done

  cd $cwd
}

no_act()
{
  test -n "$dry_run"
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
    pd sync $1 \
      || error "Not in sync: $1" 1

    rm -rf $1 \
      && note "Removed checkout $1"
  }
}


pd_run__add=y
pd__add()
{
  test -n "$1" || error "expected GIT URL" 1
  test -n "$2" || error "expected prefix" 1
  test -d "$(dirname "$2")" || error "not in a dir: $2" 1
  pd__meta put-repo $2 origin=$1 enabled=true clean=tracked sync=pull || return $?
  pd__enable $2
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
  #std_help pd "$@"
}

pd__load()
{
  for x in $(try_value "${subcmd}" "" run | sed 's/./&\ /g')
  do case "$x" in

      y )
        # set/check for Pd for subcmd
        pd=projects.yaml
        test -e "$pd" || error "No projects file $pd" 1
        p="$(realpath $pd | sed 's/[^A-Za-z0-9_-]/-/g' | tr -s '_' '-')"
        sock=/tmp/pd-$p-serv.sock
        ;;

      f )
        req_vars base subcmd
        test -n "$pd" && {
          req_vars p
          failed=/tmp/${base}-$p-$subcmd.failed
        } || {
          failed=/tmp/${base}-$subcmd.failed
        }
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

pd_init()
{
  local __load_lib=1
  . ~/bin/std.sh
  . ~/bin/main.sh
  #while test $# -gt 0
  #do
  #  case "$1" in
  #      -v )
  #        verbosity=$(( $verbosity + 1 ))
  #        incr_c
  #        shift;;
  #  esac
  #done
  . ~/bin/projectdir.inc.sh "$@"
  . ~/bin/os.lib.sh
  . ~/bin/date.lib.sh
  . ~/bin/match.sh load-ext
  . ~/bin/vc.sh load-ext
  test -n "$verbosity" || verbosity=6
  # -- pd box init sentinel --
}

pd__lib()
{
  local __load_lib=1
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
          func= \
          sock= \
          c=0

        pd_init "$@"
        shift $c

        try_subcmd && {
          pd__lib
          box_src_lib pd
          shift 1
          pd__load $subcmd "$@" || return
          $func "$@" \
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

  # Ignore 'load-ext' sub-command
  # XXX arguments to source are working on Darwin 10.8.5, not Linux?
  # fix using another mechanism:
  test -z "$__load_lib" || set -- "load-ext"
  case "$1" in load-ext ) ;; * )

      pd__main "$@"
    ;;

  esac ;;
esac

