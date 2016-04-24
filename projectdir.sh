#!/bin/sh
# Created: 2015-12-14
pd_src="$_"

set -e

version=0.0.0+20150911-0659 # script.mpe


pd_man_1__version="Version info"
pd__version()
{
  echo "$(cat $LIB/.app-id)/$version"
}
pd_als__V=version


pd__edit()
{
  $EDITOR \
    $0 \
    ~/bin/projectdir.inc.sh \
    $LIB/projectdir-meta \
    "$@"
}
#pd__als__e=edit

pd_run__meta=y
# Defer to python script for YAML parsing
pd__meta()
{
  test -n "$1" || set -- --background

  # FIXME: remove python client for a real speed improvement
  fnmatch "$1" "-*" || {
    test -x "$(which socat)" -a -e "$sock" && {
      printf -- "$*\r\n" | socat -d - "UNIX-CONNECT:$sock" \
        2>&1 | tr "\r" " " | while read line
      do
        case "$line" in
          *" OK " )
            return
            ;;
          "? "* )
            return 1
            ;;
          "!! "* )
            error "$line"
            return 1
            ;;
          "! "*": "* )
            return $(echo $line | sed 's/.*://g')
            ;;
        esac
        echo $line
      done
      return
    }
  }
  $LIB/projectdir-meta -f $pd --address $sock "$@" || return $?
}

# silent/quit
pd__meta_sq()
{
  pd__meta "$@" >/dev/null || return $?
}

pd_run__status=ybf
# Run over known prefixes and present status indicators
pd__status()
{
  local \
    registered="$(pd__list_prefixes "$1" || touch $failed)" \
    disabled="$(pd__meta list-disabled "$1" || touch $failed)" \
    enabled="$(pd__meta list-enabled "$1" || touch $failed)" \
    prefix_args= prefixes=

  test -n "$1" && prefix_args="$*" || prefix_args='*'
  test -n "$1" || set -- "$prefix_args"

  # Gobble up arguments as prefixes
  test -z "$1" || {
    while test -n "$1"
    do
      prefixes="$prefixes $(echo $1)"
      shift
      registered="$registered $(pd__list_prefixes "$1" || touch $failed)"
      disabled="$disabled $(pd__meta list-disabled "$1" || touch $failed)"
      enabled="$enabled $(pd__meta list-enabled "$1" || touch $failed)"
    done
  }

  note "Getting status for checkouts in '$prefix_args'"

  # XXX
  test "*" != "$prefixes" || {
    info "Nothing to check"
    return
  }

  info "Prefixes: $(echo "$prefixes" | tr ' ' '\n' | sort -u | tr '\n' ' ')"
  debug "Registered: $(echo "$registered" | tr ' ' '\n' | sort -u | tr '\n' ' ')"
  echo

  local union="$(echo "$prefixes $registered" | tr ' ' '\n' | sort -u)"
  for checkout in $union
  do
    test -f "$checkout" -o -h "$checkout" && {
      note "Not a checkout path at $checkout"
      continue
    }
    test -d "$checkout" || {
      echo "$prefixes" | grep -q $checkout && {
        touch $failed
        warn "Non-existant prefix? '$checkout'"
      }
      continue
    }
    test -e "$checkout/.git" || {
      note "Projectdir is not a checkout at $checkout"
      continue
    }
    pd_check $checkout || echo pd-check:$checkout >>$failed
    pd__clean $checkout || {
        warn "Checkout $checkout is not clean"
        echo pd-clean:$checkout >>$failed
    }
    echo "$registered" | grep -qF $checkout && {
      echo "$enabled" | grep -qF $checkout && {
        test -e "$checkout" || \
          note "Checkout missing: $checkout"
      } || {
        echo "$disabled" | grep -qF $checkout && {
          test ! -e "$checkout" || \
            note "Checkout to be disabled: $checkout"
        } || noop
      }
    } || {
      warn "Checkout not registered: $checkout"
    }
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
    pd_check $prefix || continue
    test -d "$prefix" || continue
    $LIB/$scriptname.sh sync $prefix || touch $failed
  done
}

pd__clean()
{
  pd_clean "$1" || return
  case "$?" in
    0|"" )
      info "OK $(__vc_status "$1")"
      #info "OK $(vc.sh status "$1")"
    ;;
    1 )
      warn "Dirty: $(__vc_status "$1")"
      return 1
    ;;
    2 )
      warn "Crufty: $(__vc_status "$1")"
      test $verbosity -gt 6 &&
        printf "$cruft\n" || noop
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
        test -z "$(vc_ufx)" && {
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
  test -n "$1" && set -- "$go_to_before/$1" || set -- "$go_to_before/*"

  backup_if_comments "$pd"
  while test ${#@} -gt 0
  do

    test -d "$1" -a -e "$1/.git" || {
      info "Skipped non-checkout path $1"
      shift
      continue
    }

    # Run over implicit enabled prefixes
    pd__meta list-enabled "$1" | while read prefix
    do
      # If exists save for next step, else disable if explicitly disabled
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

    # Run over all existing single-level prefixes, XXX: should want some depth..
    for git in $1/.git
    do
      prefix=$(dirname $git)
      match_grep_pattern_test "$prefix"

      #{ cd $prefix; git remotes; } | while read remote
      #do
      #  echo
      #done

      # Assemble metadata properties

      props=
      test -d $prefix/.git/annex && {
        props="annex=true"
      }

      props="$props $(verbosity=0;cd $prefix;echo "$(vc_remotes sh)")"
      test -n "$props" || {
        error "No remotes for $prefix"
        touch $failed
      }

      # Update existing, add newly found repos to metadata

      pd__meta_sq get-repo $prefix && {
        pd__meta update-repo $prefix $props \
          && note "Updated metadata for $prefix" \
          || {
            local r=$?;
            test $r -eq 42 && {
              info "Metadata already up-to-date for $prefix"
            } || {
              warn "Error updating $prefix with '$props'"
              touch $failed
            }
            unset r
          }
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
  pd__meta list-prefixes "$1" || return
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

# prepare Pd var, failedfn
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

  {
    pd__meta -s list-upstream "$prefix" "$@" \
      || {
        warn "No sync setting, skipping $prefix"
        return 1
      };
  } | while read remote branch
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

pd_run__enable_all=ybf
pd__enable_all()
{
  pwd=$(pwd)
  while test -n "$1"
  do
    pd__enable "$1" || touch $failed
    cd $pwd
    shift
  done
}

# Assert checkout exists, or reinitialize from Pd document.
pd_run__enable=y
pd__enable()
{
  test -z "$1" && {
    local prefixes="$(pd__meta list-enabled)"
    test -n "$prefixes" || {
        note "Nothing to check out"
        return
    }
    info "Checking out missing prefixes"
    pd__meta list-enabled | while read prefix
    do
      test -d "$prefix" || {
        note "Enabling $prefix..."
        pd__enable "$prefix" \
          && note "Enabed $prefix" \
          || error "pd-enable returned '$?'" 1
      }
    done
  } || {
    test -z "$2" || error "Surplus arguments: $2" 1
    pd__meta_sq get-repo $1 || error "No repo for $1" 1
    pd__meta -sq enabled $1 || pd__meta enable $1 || return
    test -d $1 || {
      upstream="$(pd__meta list-upstream "$1" | sed 's/^\([^\ ]*\).*$/\1/g' | head -n 1)"
      test -n "$upstream" || upstream=origin
      uri="$(pd__meta get-uri "$1" $upstream)"
      test -n "$uri" || error "No uri for $1 $upstream" 1
      git clone $uri --origin $upstream $1 || error "Cloning $uri" 1
    }
    pd__init $1 || return
  }
}

pd_run__init_all=ybf
pd__init_all()
{
  pwd=$(pwd)
  while test -n "$1"
  do
    pd__init "$1" || touch $failed
    cd $pwd
    shift
  done
}

pd_run__init=y
pd__init()
{
  test -n "$1" || error "prefix argument expected" 1
  test -z "$2" || error "Surplus arguments: $2" 1
  pd__meta_sq get-repo $1 || error "No repo for $1" 1
  pd__set_remotes $1
  cwd=$(pwd)
  cd $1
  git submodule update --init --recursive
  test ! -e .versioned-files.list || {
    echo "git-versioning check" > .git/hooks/pre-commit
    chmod +x .git/hooks/pre-commit
  }
  cd $cwd
}

# Set the remotes from metadata
pd_run__set_remotes=y
pd__set_remotes()
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
          || {
            git remote set-url $remote $url
            note "Updated remote $remote"
          }
      }
    } || {
      no_act \
        && echo "git remote add $remote $url ( ** DRY RUN ** )" \
        || {
          git remote add $remote $url
          note "Added remote $remote"
        }
    }
  done

  cd $cwd
}

no_act()
{
  test -n "$dry_run"
}

pd_run__disable_all=ybf
pd__disable_all()
{
  pwd=$(pwd)
  while test -n "$1"
  do
    pd__disable "$1" || touch $failed
    cd $pwd
    shift
  done
}

# Disable prefix. Remove checkout if clean.
pd_run__disable=y
pd__disable()
{
  test -n "$1" || error "prefix argument expected" 1
  test -z "$2" || error "Surplus arguments: $2" 1

  pd__meta_sq disabled $1 && {
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
      pd_clean $1 \
      || case "$?" in
          1 ) warn "Dirty: $(__vc_status "$1")" 1 ;;
          2 ) note "Crufty: $(__vc_status "$1")" 1 ;;
          * ) error "pd_clean error" ;;
        esac

    choice_sync_dismiss=1 \
    $LIB/$scriptname.sh sync $1 \
      || error "Not in sync: $1" 1

    rm -rf $1 \
      && note "Removed checkout $1"
  }
}


# Add repo
pd_run__add=y
pd_spc__add="add ( PREFIX | REPO PREFIX )"
pd__add()
{
  # Shift first argument to second place if only one given
  test -z "$1" || {
    test -n "$2" || set -- "" "$1"
  }

  # Check prefix arg
  set -- "$1" "$(normalize_relative $go_to_before/$2)"
  test -d $2/.git || error "Not a checkout: $2" 1

  echo 1

  # Check URL arg
  test -n "$1" && {
    noop # TODO: ping URL? validate URL format?
  } || {
    test -n "$3" && remotes="$3" || remotes="origin $(cd $2; git remote )"
    for remote in $remotes
    do
      set -- "$(cd $2; git config remote.$remote.url)" "$2" "$remote"
      test -n "$1" || continue
      note "Using remote $3 as primary repository: $1"
      break
    done
  }
  test -n "$1" || error "No URL" 1

  note "Putting repo in projectdoc.."
  pd__meta put-repo $2 origin=$1 enabled=true clean=tracked sync=pull || return $?

  note "Enabling pd repo.."
  pd__enable $2 || return $?
}


# Copy prefix from other host
pd__copy()
{
  test -n "$1" || error "expected hostname" 1
  test -n "$2" || error "expected prefix" 1

  test -d ~/.conf/project/$1 || \
      error "No dir for host $1" 1
  test -e ~/.conf/project/$1/projects.yaml || \
      error "No projectdoc for host $1" 1

  test -n "$hostname"
  $LIB/$scriptname.sh meta -sq get-repo "$2" \
    && error "Prefix '$2' already exists at $hostname" 1 || noop

  test "$hostname" != "$1" || error "You ARE at host '$2'" 1
  pd=~/.conf/project/$1/projects.yaml \
    $LIB/$scriptname.sh meta dump $2 \
    | tail -n +2 - \
    >> ~/.conf/project/$hostname/.projects.yaml
}

pd_run__run=f
pd__run()
{
  test -n "$1" || error "argument expected" 1
  case "$1" in

    '*' | bats-specs )
        local PREFIX=$(dirname $(dirname $(which bats)))
        case "$(whoami)" in
          travis )
            PATH=$PATH:/home/travis/usr/libexec/
            ;;
          * )
            PATH=$PATH:$PREFIX/libexec/
            ;;
        esac
        unset PREFIX
        count=0; specs=0
        for x in ./test/*-spec.bats
        do
          local s=$(bats-exec-test -c "$x" || error "Bats source not ok: cannot load $x" 1)
          incr specs $s
          incr count
        done
        test $count -gt 0 \
          && note "$specs specs, $count spec-files OK" \
          || { warn "No Bats specs found"; echo $1 >>$failed; }
      ;;

    '*' | bats )
        export $(hostname -s | tr 'a-z.-' 'A-Z__')_SKIP=1
        { ./test/*-spec.bats || echo $1>>$failed; } | bats-color.sh
        #for x in ./test/*-spec.bats;
        #do
        #  bats $x || echo $x >> $failed
        #done
        # ./test/*-spec.bats || { echo $1>>$failed; }
      ;;

    '*' | mk-test )
        make test || echo $1>>$failed
      ;;

    '*' | make:* )
        make $(echo $1 | cut -c 6-) || echo $1>>$failed
      ;;

    '*' | npm | npm:* | npm-test )
        npm $(echo $1 | cut -c 5-) || echo $1>>$failed
      ;;

    '*' | grunt-test | grunt | grunt:* )
        grunt $(echo $1 | cut -c 7-) || echo $1>>$failed
      ;;

    '*' | git-versioning | vchk )
        git-versioning check || echo $1>>$failed
      ;;

    sh:* )
        local cmd="$(echo "$1" | cut -c 4- | tr ':' ' ')"
        info "Using Sh '$cmd'"
        sh -c "$cmd" || echo $1>>$failed
        info "Returned $?"
      ;;

    * )
        error "No such test type $1" 1
      ;;
  esac
  test ! -e $failed || return 1
}

pd_run__test=f
pd__test()
{
  test -n "$1" || set -- $(pd__ls_tests)

  r=0
  while test -n "$1"
  do
    info "Test to run: $1"
    pd__run $1 || { r=$?; echo $1>>$failed; }
    test $r -eq 0 \
      && note "Test OK: $1" \
      || warn "Test returned ($r)"
    test 0 -eq $r || {
      trueish $choice_force || return $r
    }
    shift
  done
}

# Echo test targets for current directory
pd__ls_tests()
{
  test -e .package.sh && {
    . .package.sh
    echo $package_pd_meta_test
    return
  }

  test -e .pd-test && {
    echo $(echo "$(read_nix_style_file .pd-test)")
    return
  }

  test -e Makefile && {
    note "Using make test"
    echo "mk-test"
    return
  }

  test -e package.json && {
    note "Using npm test"
    echo "npm-test"
    return
  }

  test -e $(ls Gruntfile*|head -n 1) && {
    note "Using grunt"
    echo "grunt-test"
    return
  }

  test "$(echo test/*-spec.bats)" != "test/*-spec.bats" && {
    note "Using Bats"
    echo "bats-specs" "bats"
  }
}

pd_run__check=f
pd__check()
{
  for pd_check in pd-check{,.sh}
  do
    test -e $pd_check && {
      note "Using $pd_check"
      ./pd-check
      return $?
    }
  done

  test -n "$1" || set -- $(pd__ls_checks)

  while test -n "$1"
  do
    info "Check to run: $1"
    pd__run $1 || { r=$?; echo $1>>$failed; }
    info "Check returned ($r)"
    shift
  done
}

# Echo check targets for current directory
pd__ls_checks()
{
  test -e .pd-check && {
    echo $(cat .pd-check)
    return
  }
  test -e .package.sh && {
    . .package.sh
    echo "$package_pd_meta_check"
    return
  }
  test -n "$1" || {
    test -e .versioned-files.list && echo "git-versioning"
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
  # XXX _init is bodged, std__help pd "$@"
}

# subcmd prefix
pd_load()
{
  for x in $(try_value "${subcmd}" run | sed 's/./&\ /g')
  do case "$x" in

      y )
        # set/check for Pd for subcmd
        pd=.projects.yaml
        go_to_directory $pd
        test -e "$pd" || error "No projects file $pd" 1
        debug "PWD $(pwd), Before: $go_to_before"

        p="$(realpath "$pd" | sed 's/[^A-Za-z0-9_-]/-/g' | tr -s '_' '-')"
        sock=/tmp/pd-$p-serv.sock
        ;;

      f )
        # Preset name to subcmd failed file placeholder
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

  local tdy="$(try_value "${subcmd}" today)"
  test -z "$tdy" || {
    today=$(statusdir.sh file $tdy)
    tdate=$(date +%y%m%d0000)
    test -n "$tdate" || error "formatting date" 1
    touch -t $tdate $today
  }

  PWD=$(pwd -P)
  PATH=$PWD:$PATH

  hostname=$(hostname -s)
  uname=$(uname)

  str_load
}

pd_unload()
{
  for x in $(try_value "${subcmd}" run | sed 's/./&\ /g')
  do case "$x" in
      y )
        test -z "$sock" || {
          pd_meta_bg_teardown
          unset bgd sock
        }
        ;;
  esac; done
  unset subcmd subcmd_pref \
          def_subcmd func_exists func

  test -z "$failed" -o ! -e "$failed" || {
    test -s "$failed" && {
      count="$(sort -u $failed | wc -l | awk '{print $1}')"
      test "$count" -gt 2 && {
        warn "Failed: $(echo $(sort -u $failed | head -n 3 )) and $(( $count - 3 )) more"
        rotate-file $failed .failed
      } || {
        warn "Failed: $(echo $(sort -u $failed))"
      }
    }
    test ! -e "$failed" || rm $failed
    unset failed
    return 1
  }
}

pd_lib()
{
  test -n "$LIB" || return 13
  . $LIB/std.lib.sh
  . $LIB/str.lib.sh
  . $LIB/util.sh
  . $LIB/box.init.sh
  box_run_sh_test
  . $LIB/main.sh
  . $LIB/projectdir.inc.sh "$@"
  . $LIB/main.init.sh
  # -- pd box init sentinel --
  test -n "$verbosity" || verbosity=6
}

pd_init()
{
  local __load_lib=1
  test -n "$LIB" || return 13
  . $LIB/box.lib.sh
  . $LIB/match.lib.sh
  . $LIB/os.lib.sh
  . $LIB/date.lib.sh
  . $LIB/doc.lib.sh
  . $LIB/table.lib.sh
  . $LIB/vc.sh load-ext
  # -- pd box lib sentinel --
}


### Main

pd_main()
{
  test -n "$0" || {
    echo "No 0?"
    exit 124
  }
  local scriptname=projectdir scriptalias=pd base= \
    subcmd=$1 \
    base="$(basename "$0" .sh)" \
    LIB="$(dirname "$(realpath "$0")")"

  pd_lib "$@" || return $(( $? - 1 ))

  case "$base" in

    $scriptname | $scriptalias )

        # invoke with function name first argument,
        local bgd= \
          func_exists= \
          func= \
          sock= \
          c=0 \
          ext_sh_sub= \
          base=pd

        shift $c

        pd_init || exit $?

        try_subcmd "$@" && {
          box_src_lib pd
          shift 1
          pd_load $subcmd "$@" || return
          $subcmd_func "$@" || r=$?
          pd_unload || exit $?
          exit $r
        }

      ;;

    * )
      echo "Pd is not a frontend for $base ($scriptname)"
      exit 1
      ;;

  esac
}

case "$0" in "" ) ;; "-"* ) ;; * )

  test -z "$__load_lib" || set -- "load-ext"
  case "$1" in load-ext ) ;; * )

      pd_main "$@"
    ;;

  esac ;;
esac

