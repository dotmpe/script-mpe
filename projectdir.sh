#!/bin/sh
# Created: 2015-12-14
pd_src="$_"

set -e

version=0.0.0+20150911-0659 # script-mpe


pd_man_1__version="Version info"
pd__version()
{
  echo "$(cat $scriptdir/.app-id)/$version"
}
pd_als__V=version


pd__edit()
{
  $EDITOR \
    $0 \
    $scriptdir/projectdir*sh \
    $scriptdir/projectdir-meta \
    "$@"
}
pd_als___e=edit


pd_load__meta=y
# Defer to python script for YAML parsing
pd__meta()
{
  test -n "$1" || set -- --background
  test -n "$pd"

  fnmatch "$1" "-*" || {
    test -x "$(which socat)" -a -e "$pd_sock" && {
      printf -- "$*\r\n" | socat -d - "UNIX-CONNECT:$pd_sock" \
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
  $scriptdir/projectdir-meta -f $pd --address $pd_sock "$@" || return $?
}

# silent/quit; TODO should be able to replace with -sq
pd__meta_sq()
{
  pd__meta "$@" >/dev/null || return $?
}


pd_load__status=ybf
# Run over known prefixes and present status indicators
pd__status()
{
  pd__list_prefixes "$1" > $PD_TMP/prefixes.list
  pd__meta list-disabled "$1" > $PD_TMP/prefix-disabled.list
  pd__meta list-enabled "$1" > $PD_TMP/prefix-enabled.list

  #local \
  #  registered="$(pd__list_prefixes "$1" || touch $failed)" \
  #  disabled="$(pd__meta list-disabled "$1" || touch $failed)" \
  #  enabled="$(pd__meta list-enabled "$1" || touch $failed)" \
  local \
    prefix_args= prefixes=

  test -n "$1" && prefix_args="$*" || prefix_args='*'
  #test -n "$1" || set -- "$prefix_args"

  # Gobble up arguments as prefixes
  test -z "$1" && {
    prefixes="$(cat $PD_TMP/prefixes.list)"
  } || {
    while test -n "$1"
    do
      grep -qF "$1" $PD_TMP/prefixes.list && {
        prefixes="$prefixes $(echo $1)"
      } || {
        warn "Not a known prefix $1"
      }
      shift
      #registered="$registered $(pd__list_prefixes "$1" || touch $failed)"
      #disabled="$disabled $(pd__meta list-disabled "$1" || touch $failed)"
      #enabled="$enabled $(pd__meta list-enabled "$1" || touch $failed)"
    done
  }

  #note "Getting status for checkouts in '$prefix_args'"
  #info "Prefixes: $(echo "$prefixes" | unique_words)"
  #debug "Registered: $(echo "$registered" | unique_words)"
  #local union="$(echo "$prefixes $registered" | words_to_unique_lines )"
  for checkout in $prefixes
    # XXX union
  do

    test -f "$checkout" -o -h "$checkout" && {
      note "Not a checkout path at $checkout"
      continue
    }
    test -d "$checkout" || {
      grep -qF $checkout $PD_TMP/prefixes.list || {
        touch $failed
        warn "Non-existant prefix? '$checkout'"
      }
      continue
    }
    test -e "$checkout/.git" || {
      note "Projectdir is not a checkout at $checkout"
      continue
    }
    #statusdir.sh assert-state 'project/'$checkout'/tags'='[]'

    # FIXME: merge with pd-check? Need fast access to lists..
    #pd_check $checkout || echo pd-check:$checkout >>$failed

    pd_meta_clean_mode=
    pd__clean $checkout || {
      echo pd-clean:$checkout >>$failed
      #statusdir.sh assert-state \
      #  'project/'$checkout'/clean'=false
      #statusdir.sh assert-state \
      #  'project/'$checkout'/tags[]'=to-clean
    }

    grep -qF $checkout $PD_TMP/prefix-enabled.list && {
      test -e "$checkout" || {
        note "Checkout missing: $checkout"
        statusdir.sh assert-json \
          'project/'$checkout'/tags[]=to-enable'
      }
    } || {
      grep -qF $checkout $PD_TMP/prefix-disabled.list && {
        test ! -e "$checkout" || {
          note "Checkout to be disabled: $checkout"
          statusdir.sh assert-json \
            'project/'$checkout'/tags[]=to-clean'
        }
      } || noop
    }

  done
}


pd_load__clean=y
pd__clean()
{
  local R=0

  test -z "$2" || pd_meta_clean_mode="$2"
  test -n "$pd_meta_clean_mode" \
    || pd_meta_clean_mode="$( pd__meta clean-mode "$1" )"

  info "Checkout: $checkout, Clean Mode: $pd_meta_clean_mode"

  pd_clean "$1" || R=$?;

  case "$R" in
    0|"" )
        info "OK $(vc__stat "$1")"
      ;;
    1 )
        warn "Dirty: $(vc__stat "$1")"
        return 1
      ;;
    2 )
        cruft_lines="$(echo $(echo "$cruft" | wc -l))"
        test $verbosity -gt 6 \
          && {
            warn "Crufty: $(vc__stat "$1"):"
            printf "$cruft\n"
          } || {
            warn "Crufty: $(vc__stat "$1"), $cruft_lines path(s)"
          }
        return 2
      ;;
    * )
        error "pd_clean error"
        return -1
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
        test -z "$(vc__ufx)" && {
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


# Regenerate local package metadata files and scripts
pd_load__regenerate=dfp
pd__regenerate()
{
  set -- "$(normalize_relative "$go_to_before/$1")"
  exec 6>$failed
  ( cd $1 && pd_regenerate "$1" )
  exec 6<&-
  test -s "$failed" || rm $failed
}


# Given existing checkouts upate local scripts and then projdoc
pd_load__update=yfp
pd__update()
{
  set -- "$(normalize_relative "$go_to_before/$1")"
  local cwd=$(pwd)

  exec 3>$failed
  ( cd $1 && pd_regenerate "$1" )
  exec 3<&-
  test -s "$failed" || rm $failed

  cd $cwd

  # Update projectdocument with repo remotes etc
  pd__meta_sq get-repo $1 && {

    note "Updating prefix $1"
    pd__update_repo $1
  } || {

    note "Adding prefix $1"
    pd__add_new $1
  }
}

# Add/remove repos, update remotes at first level. git only.
pd_load__update_all=yfb
pd__update_all()
{
  test -n "$1" \
    && set -- "$go_to_before/$1" \
    || set -- "$go_to_before/*"
  set -- "$(normalize_relative "$1")"

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

          pd__meta disable $prefix \
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

      # Assemble metadata properties
      pd__update $prefix

    done

    shift
  done
}

pd_load__find=y
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

pd_load__list_prefixes=y
pd__list_prefixes()
{
  test -z "$2" || error "Surplus arguments: $2" 1
  pd__meta list-prefixes "$1" || return
}

pd_load__compile_ignores=y
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
pd_load__sync=yf
# Update remotes and check refs
pd__sync()
{
  test -n "$1" || error "prefix argument expected" 1
  remotes=/tmp/pd--sync-$(uuidgen)
  prefix=$1

  shift 1
  test -n "$1" || set -- $(vc__list_local_branches $prefix)
  pwd=$(pwd -P)

  cd $pwd/$prefix

  test -d .git || error "Not a standalone .git: $prefix" 1

  test ! -d .git/annex || {
    git annex version >/dev/null || {
      error "GIT Annex dir but no git-annex" 1
    }
    git annex sync || r=$?
    test -n "$r" || {
      echo "annex-sync:$prefix" >>$failed
      return $r
    }
  }

  cd $pwd

  # XXX: look into git config for this: git for-each-ref --format="%(refname:short) %(upstream:short)" refs/heads
  {
    pd_list_upstream || {
      warn "No sync setting, skipping $prefix"
      return 1
    }
  } | while read remote branch
  do

    fnmatch "*annex*" $branch && continue || noop


    cd $pwd/$prefix

    ( test -e .git/FETCH_HEAD && younger_than .git/FETCH_HEAD $PD_SYNC_AGE ) || {
      git fetch --quiet $remote || {
        error "fetching $remote"
        echo "fetch:$remote" >>$failed
        continue
      }
    }


    local remoteref=$remote/$branch

    echo $remoteref >>$remotes

    git show-ref --quiet $remoteref || {
      test -n "$choice_sync_push" && {
        git push $remote +$branch
      } || {
        error "Missing remote branch in $prefix: $remoteref"
        echo "missing:$prefix:$remoteref" >>$failed
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
      trueish "$dry_run" \
        && echo "ahead:$prefix:$remoteref:$ahead" >>$failed \
        || {

          git push $remote $branch || {

            echo "sync-fail:$prefix:$remoteref:$?" >>$failed
            continue
          }
        }
    }

    test $behind -eq 0 || {
      # XXX: ignore upstream commits?
      test -n "$choice_sync_dismiss" \
        || {
          note "$prefix behind of $remote#$branch by $behind commits"
          test -n "$dry_run" || touch $failed
        }
    }

  done

  test -s "$remotes" || {
    error "No remotes for $pwd/$prefix"
    return 1
  }
  remote_cnt=$(wc -l $remotes | awk '{print  $1}')
  test $remote_cnt -gt 0 || echo 'remotes:0' >>$failed

  test -s "$failed" \
    && error "Not in sync: $prefix" \
    || info "In sync with at least one remote: $prefix"
}

pd_load__enable_all=ybf
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
pd_load__enable=y
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
    pd__meta -sq enabled $1 || pd__meta -q enable $1 || return
    test -d $1 || {
      upstream="$(pd__meta list-upstream "$1" | sed 's/^\([^\ ]*\).*$/\1/g' | head -n 1)"
      test -n "$upstream" || upstream=origin
      uri="$(pd__meta get-uri "$1" $upstream)"
      test -n "$uri" || error "No uri for $1 $upstream" 1
      git clone $uri --origin $upstream $1 || error "Cloning $uri" 1
    }
    pd__init $1 || return
  }
  note "Initialized '$1'"
}

pd_load__init_all=ybf
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

# Given existing checkout, update local .git with remotes, regen hooks.
pd_load__init=yfp
pd__init()
{
  test -n "$1" || error "prefix argument expected" 1
  test -z "$2" || error "Surplus arguments: $2" 1
  pd__meta_sq get-repo $1 || error "No repo for $1" 1

  pd__set_remotes $1

  (
    cd $1
    git submodule update --init --recursive

    # Regenerate .git/info/exclude
    vc__regenerate || echo "init:vc-regenerate:$1" >>$failed

    test ! -e .versioned-files.list || {
      echo "git-versioning check" > .git/hooks/pre-commit
      chmod +x .git/hooks/pre-commit
    }
  )
}

# Set the remotes from metadata
pd_load__set_remotes=y
pd__set_remotes()
{
  test -n "$1" || error "prefix argument expected" 1
  test -z "$2" || error "Surplus arguments: $2" 1

  note "Syncing local remotes with $pd repository"
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

pd_load__disable_all=ybf
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
pd_load__disable=yf
pd__disable()
{
  test -n "$1" || error "prefix argument expected" 1
  test -z "$2" || error "Surplus arguments: $2" 1


  pd__meta_sq disabled "$1" && {
    info "Already disabled: '$1'"
  } || {
    pd__meta disable $1 && note "Disabled $1"
  }

  test ! -d "$1" && {
    info "No checkout, nothing to do"
  } || {
    note "Found checkout, getting status.. (Clean-Mode: $(pd__meta clean-mode $1))"

    pd__clean $1 || return $?

    choice_sync_dismiss=1 \
    $scriptdir/$scriptname.sh sync $1 || return $?

    trueish "$dry_run" \
      && {
        echo "dry-run:rm:$1" >>$failed
        note "** DRY_RUN **: checkout to be removed $1"
      } || {
        rm -rf $1 \
          && note "Removed checkout $1"
      }
  }
}


# Add or update SCMs of a repo
# Arguments checkout dir prefix, url and prefix, or remote name, url and prefix.
pd_load__add=y
pd_spc__add="add ( PREFIX | REPO PREFIX | NAME REPO PREFIX )"
pd__add()
{
  # Shift args to right, padding with empty arguments
  while test ${#} -ne 3
  do
    set -- "" "$@"
  done

  # Check prefix or url arg
  set -- "$1" "$2" "$(normalize_relative "$go_to_before/$3")"
  test -n "$2" -o -d $3/.git || error "No repo, and not a checkout: $3" 1

  # Set default args for single remote
  test -n "$1" || {
    test -z "$2" || set -- "origin" "$2" "$3"
  }

  # Check URL arg, add/update a repo remote if given
  test -z "$2" || props="remote_$1=$2"

  pd__meta_sq get-repo "$3" 1>/dev/null || {
    pd__meta update-repo "$3" $props
  } || {
    pd__add_new "$3" $props
  }
  # XXX after pd-add, perhaps enable+init+regenerate
  #trueish "$choice_interactive" && {
  #  pd__init
  #}
}

# Add a new item to the projectdoc, resolving some default values
# Fail if prefix already in use
pd_load__add_new=f
pd__add_new()
{
  local prefix=$1; shift; local props="$@"

  # Concat props as k/v, and sort into unique mapping later; last value wins
  # FIXME: where ar the defaults: host and user defined, and project defined.
  props="clean=tracked sync=true $@"

  info "New repo $prefix, props='$(echo $props)'"

  pd__meta put-repo $prefix $props \
    && note "Added metadata for $prefix" \
    || {
      error "Unexpected error adding repo $?" $?
      echo "add-new:$prefix" >>$failed
    }

  # XXX: enabled?
}

# Given prefix and optional props, update metadata. Props is prepended
# and so may be overruled by host/env. To update metadata directly,
# use pd__meta{,_sq} update-repo.
pd_load__update_repo=f
pd__update_repo()
{
  local cwd=$(pwd); prefix=$1; shift; local props="$@"

  #test -d "$prefix/.git" || {
  #  trueish "$choice_enable" && {
  #    note "Enabling pd repo.."
  #    pd__enable $3 || return $?
  #  }
  #}

  test -d "$prefix/.git" && props="$props enabled=true"

  test -d $prefix/.git/annex && {
    props="$props annex=true"
  }

  # scan checkout remotes

  # FIXME: move here props="$props $(verbosity=0;cd $1;echo "$(vc__remotes sh)")"

  local remotes=
  for remote in $(cd $prefix; git remote)
  do
    remotes="$remotes remote_$remote=$(cd $prefix; git config remote.$remote.url)"
  done

  test -n "$remotes" && props="$props $remotes" || {
    error "No remotes for $prefix"
    echo "update:no-remotes:$prefix" >>$failed
    return
  }

  trueish "$dry_run" && warn "** DRY-RUN **" 1

  # Update existing, add newly found repos to metadata

  pd__meta update-repo $prefix $props \
    && note "Updated metadata for $prefix" \
    || {
      local r=$?;
      test $r -eq 42 && {
        info "Metadata already up-to-date for $prefix"
      } || {
        warn "Error updating $prefix with '$(echo $props)'"
        echo "update-repo:$prefix:$r" >>$failed
      }
      unset r
    }
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
  $scriptdir/$scriptname.sh meta -sq get-repo "$2" \
    && error "Prefix '$2' already exists at $hostname" 1 || noop

  test "$hostname" != "$1" || error "You ARE at host '$2'" 1
  pd=~/.conf/project/$1/projects.yaml \
    $scriptdir/$scriptname.sh meta dump $2 \
    | tail -n +2 - \
    >> ~/.conf/project/$hostname/.projects.yaml
}


pd_load__run=yiYI
# Run (project) helper commands and track results
pd_spc__run='[ PREFIX | [:]TARGET ]...'
pd__run()
{
  test -n "$pd_prefix" -a -n "$pd_root" || error "Projectdoc context expected" 1
  test -n "$1" || error "argument expected" 1
  record_env_keys pd-run pd-subcmd pd-env

  local status_key= states=

  info "Pd targets requested: $*"

  # TODO filter out prefixes from requested targets

  cd $pd_prefix

  while test -n "$1"
  do
    status_key=$1 states= result=0

    info "Next target: $1"
    record_env_keys pd-target pd-run pd-subcmd pd-env
    pd_debug start $1 pd-target pd_prefix

    . $scriptdir/$scriptname-run.inc.sh $1 && {
      echo "$1" >&3
    } || {
      result=$?
      echo "$1" >&5
    }

    #    && pd_update_status $status_key/result=0 $states \
    #    || {
    #      pd_update_status $status_key/result=$? $states
    #      echo $1 >&6
    #    }

    record_env_keys pd-target pd-run pd-subcmd pd-env

    pd_debug end $1 pd-target pd_prefix

    shift 1
  done

  cd $pd_root
}


pd_man_1__test="Run test targets (for single prefix)"
pd_load__test=yiI
pd__test()
{
  test -n "$pd_prefix" -a -n "$pd_root" || error "Projectdoc context expected" 1
  test -n "$1" || set -- $(cd $pd_prefix; pd__ls_targets test)

  info "Tests to run: $*"
  pd__run "$@"
  return $?
}


pd_load__check_all=ybf
# Check if setup, with remote refs
pd__check_all()
{
  test -z "$2" || error "Surplus arguments: $2" 1
  note "Checking prefixes"
  pd__meta list-prefixes "$1" | while read prefix
  do
    pd_check $prefix || continue
    test -d "$prefix" || continue
    $scriptdir/$scriptname.sh sync $prefix || touch $failed
  done
}


pd_load__check=yiI
pd__check()
{
  test -n "$pd_prefix" -a -n "$pd_root" || error "Projectdoc context expected" 1
  test -n "$1" || set -- $(cd $pd_prefix;pd__ls_targets check)

  info "Checks to run: $*"
  pd__run "$@"
  return $?
}


pd_load__show=iy
pd_spc__show="[ PREFIX ]..."
# Print Pdoc record and main section of package meta file.
pd__show()
{
  while test -n "$1"
  do

    test "$dry_run" && {
      
      echo "pd:show:$1"

    } || {

      note "Showing main package data for '$1'"

      pd__meta get-repo $1 | \
        jsotk.py -I json -O yaml --pretty --output-prefix repositories/$1 merge - -

      local metaf=
      update_package "$1" && {

        test -n "$metaf" || error metaf 1
        test -e "$metaf" || error $metaf 1

        jsotk.py --output-prefix package -I yaml -O yaml --pretty objectpath \
          $metaf '$.*[@.main is not None]'
      }
    }

    shift
  done
}

pd__ls_sets()
{
  for name in $pd_sets
  do
    echo "$name"
  done
}

pd__ls_comp()
{
  echo "Init comp: $pd_init__sets"
  echo "Check comp: $pd_check__sets"
  echo "Test comp: $pd_test__sets"
}


pd_spc__ls_targets="[ NAME ]..."
# Gather targets for given named set(s)
pd__ls_targets()
{
  local name= value=
  test -n "$1" || set -- $(pd__ls_sets)
  while test -n "$1"
  do
    name=$1; shift
    read_if_exists .pd-$name && continue
    pd_package_meta "$name" && continue
    pd_autodetect $name
  done | words_to_lines
}
pd_load__ls_targets=dpi



# ----


pd__usage()
{
  echo 'Usage: '
  echo "  $scriptname.sh <cmd> [<args>..]"
  echo
}

pd__help()
{
  test -z "$1" && {
    choice_global=1 std__help "$@"
  } || {
    echo_help $1
  }
}

# Setup for subcmd; move some of this to box.lib.sh eventually
pd_load()
{
  test -n "$pd" || pd=.projects.yaml
  # Per subcmd init
  for x in $(try_value "${subcmd}" load | sed 's/./&\ /g')
  do case "$x" in

    p ) # Set package path at prefix; should imply y or d
        test -e $go_to_before/package.yaml && update_package "$go_to_before"
        test -e "$go_to_before/.package.sh" && . $go_to_before/.package.sh
        test -n "$package_id" && {
          note "Found package '$package_id'"
        } || {
          package_id="$(basename $(realpath $go_to_before))"
          note "Using package ID '$package_id'"
        }
      ;;

    d ) # Stub for no Pd context
        go_to_before=. pd_prefix=. pd_realpath= pd_root=
      ;;

    y )
        # look for Pd Yaml and set env: pd_prefix, pd_realpath, pd_root
        # including socket path, to check for running Bg metadata proc
        pd_finddoc $pd
      ;;

    Y )
        # given we have a Pdoc, expand any arguments as prefixes

        test -n "$1" || {
          test "." = "$go_to_before" && {
            set -- '*' # default arg if within pd_root
          } || {
            set -- "." # default arg in subdir
          }; }

        while test -n "$1"
        do
          for expanded_arg in $go_to_before/$1
          do
            test -d "$expanded_arg" || continue
            strip_trail=1 normalize_relative $expanded_arg
          done
          shift
        done \
          | words_to_unique_lines > $arguments
      ;;

    f )
        # Preset name to subcmd failed file placeholder
        # include realpath of projectdoc (p)
        test -n "$pd" && {
          req_vars p
          failed=$(setup_tmp .failed -$p-$subcmd-$(uuidgen))
        } || failed=$(setup_tmp .failed)
      ;;

    i ) 
        test -n "$pd_trgtpref" || pd_trgtpref="$(try_value "$subcmd" trgtpref)"
        test -n "$pd_root" && { 
          # expect Pd Context; setup IO paths (req. y)
          req_vars pd pd_cid pd_realpath pd_root pd_sid \
            || error "Projectdoc context expected" 1

          io_id=-${pd_cid}-${subcmd}-${pd_sid}
        } || {
          io_id=-subcmd-$(uuidgen)
        }
        for io_name in passed skipped error failed arguments
        do
          eval $io_name=$(setup_tmp .$io_name $io_id)
        done
        export passed skipped error failed arguments
      ;;

    I ) # setup IO descriptors (requires i before)
        req_vars pd pd_cid pd_realpath pd_root \
          passed skipped error failed arguments
        exec 3>$passed
        exec 4>$skipped
        exec 5>$error
        exec 6>$failed
        # TODO: setup to subcmd handlers can interact with argv arguments
        touch $arguments
      ;;

    b )
        # run metadata server in background for subcmd
        pd_meta_bg_setup
      ;;

    a ) 
        # Set default args. Value can be literal or function.
        local pd_default_args="$(eval echo "\"\$$(try_local $subcmd defargs)\"")"
        pd_default_args "$pd_default_args" "$@" >> $arguments
      ;;

    g ) 
        # Set default args based on file glob(s), or expand short-hand arguments 
        # by looking through the globs for existing paths
        pd_trgtglob="$(eval echo "\"\$$(try_local $subcmd trgtglob)\"")"
        pd_globstar_search "$pd_trgtglob" "$@" >> $arguments
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

  test -n "$PD_TMP" || {
    pwdref=$(pwd -P | tr -C 'A-Za-z0-9_-' '-')
    test -n "$RAM_DISK_ROOT" && {
      PD_TMP=$RAM_DISK_ROOT/pd/temp/$pwdref
    } || {
      PD_TMP=$(cd /tmp;pwd -P)/pd/$pwdref
    }
    mkdir -vp $PD_TMP
    rm -rf $PD_TMP/*
  }

  PWD=$(pwd -P)
  PATH=$PWD:$PATH

  hostname=$(hostname -s)
  uname=$(uname)

  str_load
}

# Close subcmd; move some of this to box.lib.sh eventually
pd_unload()
{
  local subcmd_result=0

  for x in $(try_value "${subcmd}" load | sed 's/./&\ /g')
  do case "$x" in
      F )
          exec 6<&-
        ;;
      i ) # remove named IO buffer files; set status vars
          clean_io_lists passed skipped error failed arguments
          unset passed skipped error failed arguments
          pd_report passed skipped error failed arguments || subcmd_result=$?
        ;;
      I )
          exec 3<&-
          exec 4<&-
          exec 5<&-
          exec 6<&-
        ;;
      y )
          test -z "$pd_sock" || {
            pd_meta_bg_teardown
            unset bgd pd_sock
          }
        ;;
  esac; done

  unset subcmd subcmd_pref \
          def_subcmd func_exists func

  return $subcmd_result
}

pd_lib()
{
  test -n "$scriptdir" || return 13
  export SCRIPTPATH=$scriptdir
  . $scriptdir/util.sh
  lib_load sys os std str src main meta
  . $scriptdir/box.init.sh
  box_run_sh_test
  . $scriptdir/projectdir.inc.sh "$@"
  . $scriptdir/projectdir-bats.inc.sh
  . $scriptdir/projectdir-git.inc.sh
  . $scriptdir/projectdir-git-versioning.inc.sh
  . $scriptdir/main.init.sh
  # -- pd box init sentinel --
  test -n "$verbosity" || verbosity=6
}

pd_init()
{
  local __load_lib=1
  test -n "$scriptdir" || return 13
  lib_load box match date doc table
  . $scriptdir/vc.sh load-ext
  # -- pd box lib sentinel --
}


### Main

pd_main()
{
  mkdir -p /tmp/env-keys
  {
    env
    set
    local
  } | sed 's/=.*$//' | sort -u > /tmp/env-keys/pd-env

  test -n "$0" || {
    echo "No 0?"
    exit 124
  }
  local scriptname=projectdir scriptalias=pd base= \
    subcmd=$1 \
    base="$(basename "$0" .sh)" \
    scriptdir="$(dirname "$(realpath "$0")")"

  pd_lib "$@" || return $(( $? - 1 ))

  case "$base" in

    $scriptname | $scriptalias )

        # invoke with function name first argument,
        local bgd= \
          func_exists= \
          func= \
          pd_sock= \
          c=0 \
          ext_sh_sub= \
          base=pd

        shift $c

        pd_init || exit $?

        try_subcmd "$@" && {

          record_env_keys pd-subcmd pd-env

          box_src_lib pd
          shift 1
          pd_load "$@" || return

          test -z "$arguments" -o ! -s "$arguments" || {
            set -f
            set -- $(cat $arguments | lines_to_words)
            set +f
          }

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

