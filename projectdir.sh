#!/bin/sh
# Created: 2015-12-14
pd_src="$_"

set -e

version=0.0.3-dev # script-mpe


pd_man_1__version="Version info"
pd__version()
{
  echo "$(cat $scriptdir/.app-id)/$version"
}
pd_als__V=version


pd_man_1__edit="Edit script-files, append ARGS to EDITOR arguments. "
pd_spc__edit="edit [ARGS]"
pd__edit()
{
  $EDITOR \
    $0 \
    $scriptdir/projectdir*sh \
    $scriptdir/projectdir-meta \
    $scriptdir/meta.lib.sh \
    "$@"
}
pd_als___e=edit


pd_load__meta=y
pd_man_1__meta="Defer a command to the python script for YAML parsing"
pd__meta()
{
  test -n "$1" || set -- --background
  test -n "$pd" || error pd 2

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
  test -n "$pd_sock" && set -- --address $pd_sock "$@"
  $scriptdir/projectdir-meta -f $pd "$@" || return $?
}

pd_man_1__meta_sq="double silent/quiet; TODO should be able to replace with -sq"
pd__meta_sq()
{
  pd__meta "$@" >/dev/null || return $?
}


pd_man_1__status="List prefixes and their state(s)"
pd_spc__status='st|stat|status [ PREFIX | [:]TARGET ]...'
pd__status()
{
  test -n "$pd_prefix" -a -n "$pd_root" || error "Projectdoc context expected" 1
  info "Pd targets requested: $*"
  info "Pd prefixes requested: $(cat $prefixes | lines_to_words)"

  test -s "$options" || format_yaml=1

  # XXX: fetching the state requires all branches to have status/result set.
  #pd__meta update-states
  # TODO: also export for monitoring

  while read pd_prefix
  do
    test -f "$checkout" -o -h "$checkout" && {
      echo "pd:status:$pd_prefix" >$failed
      note "Not a checkout path at $checkout"
      continue
    }

    note "pd-prefix=$pd_prefix ($CWD)"

    trueish "$format_yaml" && {

      {
        # Read from tree, note status != 0 as failures.
        pd_fetch_status "$pd_prefix" | read_nix_style_file \
          | jsotk.py -I yaml -O pkv - | read_nix_style_file | tr '=' ' ' | while read var stat
        do
          test "$var" = "None" && continue
          test "$stat" = "None" && continue
          test "$stat" -eq 0 || {
            echo "$pd_prefix" >> $failed
            warn "$pd_prefix: $(echo $var | cut -c8-)"
            #warn "$pd_prefix: $var"
          }
        done

      } || echo "pd:status:$pd_prefix" >>$failed

    }

    trueish "$format_stm_yaml" && {
      note "TODO"
    }

  done < $prefixes

  cd $pd_realdir
}
pd_load__status=yiIaop
pd_defargs__status=pd_registered_prefix_target_args
pd_optsv__status=pd_options_v
pd_als__stat=status
pd_als__st=status


pd_load__status_old=ybf
# Run over known prefixes and present status indicators
pd__status_old()
{
  pd__list_prefixes "$1" > $PD_TMPDIR/prefixes.list
  pd__meta list-disabled "$1" > $PD_TMPDIR/prefix-disabled.list
  pd__meta list-enabled "$1" > $PD_TMPDIR/prefix-enabled.list

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
    prefixes="$(cat $PD_TMPDIR/prefixes.list)"
  } || {
    while test -n "$1"
    do
      grep -qF "$1" $PD_TMPDIR/prefixes.list && {
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
      grep -qF $checkout $PD_TMPDIR/prefixes.list || {
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

    grep -qF $checkout $PD_TMPDIR/prefix-enabled.list && {
      test -e "$checkout" || {
        note "Checkout missing: $checkout"
        statusdir.sh assert-json \
          'project/'$checkout'/tags[]=to-enable'
      }
    } || {
      grep -qF $checkout $PD_TMPDIR/prefix-disabled.list && {
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

  test -n "$1" || error "Prefix expected" 1
  test -z "$2" || pd_meta_clean_mode="$2"
  test -n "$pd_meta_clean_mode" \
    || pd_meta_clean_mode="$( pd__meta clean-mode "$1" )"

  info "Checkout: $1, Clean Mode: $pd_meta_clean_mode"

  pd_auto_clean "$1" || {
    error "Auto-clean failure for checkout '$1'"
    return 1
  }

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


pd_man_1__disable_clean="drop clean checkouts and disable repository"
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


pd_man_1__regenerate="Regenerate local package metadata files and scripts"
pd_load__regenerate=dfP
#pd_load__regenerate=yfip
pd__regenerate()
{
  test -n "$pd_prefix" || error pd_prefix 1
  test -n "$1" || set -- .
  set -- "$(normalize_relative "$pd_prefix/$1")"
  note "Regenerating meta files in '$1' ($(pwd))"
  exec 6>$failed
  pd_regenerate "$1"
  exec 6<&-
  test -s "$failed" || rm $failed
}


pd_man_1__update="Given existing checkouts upate local scripts and then projdoc"
pd_load__update=yfP
pd__update()
{
  test -n "$1" || set -- .
  set -- "$(normalize_relative "$pd_prefix/$1")"
  local cwd=$(pwd)

  note "Regenerating in $1"

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
    pd__add_new $1 $(cd "$cwd/$1"; vc.sh remotes sh)
  }
}

pd_man_1__updatE_all="Add/remove repos, update remotes at first level. git only."
pd_load__update_all=yfb
pd__update_all()
{
  test -n "$1" \
    && set -- "$pd_prefix/$1" \
    || set -- "$pd_prefix/*"
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

pd__list()
{
  pd__meta list-prefixes | read_nix_style_file | while read prefix
  do
    echo $prefix
    # TODO: echo table; id name main envs..
  done
}

pd__list_all()
{
  test -d "$UCONF/project/" || error list-all-UCONF 1
  local pd=
  {
    for pd in $UCONF/project/*/*.y*ml
    do
      pd__meta list-prefixes
    done
  } | sort -u
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
  remotes=/tmp/pd--sync-$(get_uuid)
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
    set -- "$(strip_trail=1 normalize_relative "$1")"
    pd__meta_sq get-repo $1 || error "No repo for $1" 1
    pd__meta -sq enabled $1 || pd__meta -q enable $1 || return
    test -d $1 || {
      upstream="$(pd__meta list-upstream "$1" | sed 's/^\([^\ ]*\).*$/\1/g' | head -n 1)"
      test -n "$upstream" || upstream=origin
      uri="$(pd__meta get-uri "$1" $upstream)"
      test -n "$uri" || error "No uri for $1 $upstream" 1
      branch=$(jsotk path "$pd" repositories/"$1"/default -Opy 2>/dev/null || echo master)
      git clone $uri --origin $upstream --branch $branch $1 \
        || error "Cloning $uri ($upstream/$branch)" 1
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
pd_load__init=yfP
pd__init()
{
  test -n "$1" || error "prefix argument expected" 1
  test -d "$1" || error "No checkout for $1" 1
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


pd_man_1__init_new="Run init_new targets (for single prefix)"
pd_load__init_new=yiIap
pd_defargs__init_new=pd_prefix_target_args
pd__init_new()
{
  init -n "$pd_prefix" -a -n "$pd_root" || error "Projectdoc context expected" 1
  init -n "$1" || set -- $(pd__ls_targets init 2>/dev/null)
  info "Tests to run ($pd_prefixes): $*"
  pd_run_suite init "$@" || return $?
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
    note "Found checkout, running pd-clean..."
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
  set -- "$1" "$2" "$(normalize_relative "$pd_prefix/$3")"
  test -n "$2" -o -d $3/.git || error "No repo, and not a checkout: $3" 1

  # Set default args for single remote
  test -n "$1" || {
    test -z "$2" || set -- "origin" "$2" "$3"
  }

  # Check URL arg
  test -n "$2" && {
    # add/update a repo remote if arg given
    props="remote_$1=$2"
  } || {
    # Or fill out all remotes
    props="$(verbosity=0 ; cd $3 && vc remotes sh)"
  }

  note "Prefix: $3"
  note "Repo: $2"
  note "Remote: $1"
  note "Properties: $props"

  pd__meta_sq get-repo "$3" 1>/dev/null || {
    pd__meta update-repo "$3" $props
  } || {
    pd__add_new "$3" $props
  }
  # TODO: after pd-add, perhaps enable+init+regenerate
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
  props="clean=tracked sync=true $props"

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
  test -n "$hostname" || error "expected env hostname" 1
  for host in $hostname $1
  do
    test -d ~/.conf/project/$host || \
        error "No dir for host $host" 1
    test -e ~/.conf/project/$1/projects.yaml || \
        error "No projectdoc for host $1" 1
  done
  test "$hostname" != "$1" || error "You ARE at host '$2'" 1


  $scriptdir/$scriptname.sh meta -sq get-repo "$2" \
    && error "Prefix '$2' already exists at $hostname" 1 || noop

  pd=~/.conf/project/$1/projects.yaml \
    $scriptdir/$scriptname.sh meta dump $2 \
    | tail -n +2 - \
    >> ~/.conf/project/$hostname/projects.yaml \
    && note "Copied $2 from $1 to $hostname projects YAML"
}


pd_load__run=yiIap
pd_defargs__run=pd_prefix_target_args
# Run (project) helper commands and track results
pd_spc__run='[ PREFIX | [:]TARGET ]...'
pd__run()
{
  test -n "$pd_prefix" -a -n "$pd_root" || error "Projectdoc context expected" 1
  #record_env_keys pd-run pd-subcmd pd-env
  info "Pd targets requested: $*"
  info "Pd prefixes requested: $(cat $prefixes | lines_to_words)"


  while read pd_prefix
  do
    key_pref=repositories/$(normalize_relative "$pd_prefix")
    cd $pd_realdir/$pd_prefix

    # Iterate targets

    set -- $(cat $arguments | lines_to_words )
    test -n "$1" || {
      info "Setting targets to states of 'init' for '$pd_root/$pd_prefix'"
      set -- $(pd__ls_targets init 2>/dev/null)
    }

    while test -n "$1"
    do
      fnmatch ":*" "$1" && target=$(echo "$1" | cut -c2- ) || target=$1

      test -n .package.sh || error package 31

      #note "1=$1 target=$target"

      #record_env_keys pd-target pd-run pd-subcmd pd-env
      #pd_debug start $target pd-target pd_prefix

      (
        export $(pd__env)
        subcmd="$subcmd $pd_prefix#$target" \
          pd_run $1 && {
            echo "$pd_prefix#$target" >&3
          } || {
            echo "$pd_prefix#$target" >&5
          }
      )

      #pd_debug end $target pd-target pd_prefix

      shift

    done
  done < $prefixes

  cd $pd_realdir
}


pd_man_1__run_suite="Run test targets (for single prefix)"
pd_load__run_suite=yiIp
pd__run_suite()
{
  test -n "$pd_prefix" -a -n "$pd_root" || error "Projectdoc context expected" 1
  test -n "$1" || error "Suite name expected" 1
  local suite_name=$1
  shift
  # TODO: handle prefixes
  test -z "$2" || error surplus-args 1
  pd_run_suite $1 $(pd__ls_targets $1 2>/dev/null)
}


pd_man_1__test="Run test targets (for single prefix)"
pd_load__test=yiIap
pd_defargs__test=pd_prefix_target_args
pd__test()
{
  test -n "$pd_prefix" -a -n "$pd_root" || error "Projectdoc context expected" 1
  test -n "$1" || set -- $(pd__ls_targets test 2>/dev/null)
  info "Tests to run ($pd_prefixes): $*"
  pd_run_suite test "$@"
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


pd_load__check=yiIap
pd_defargs__check=pd_registered_prefix_target_args
pd__check()
{
  test -n "$pd_prefix" -a -n "$pd_root" || error "Projectdoc context expected" 1
  test -n "$1" || set -- $(pd__ls_targets check 2>/dev/null)
  info "Checks to run ($pd_prefixes): $*"
  pd_run_suite check "$@"
}


pd_load__build=yiIap
pd_defargs__build=pd_registered_prefix_target_args
pd__build()
{
  test -n "$pd_prefix" -a -n "$pd_root" || error "Projectdoc context expected" 1
  test -n "$1" || set -- $(pd__ls_targets build 2>/dev/null)
  info "Checks to run ($pd_prefixes): $*"
  pd_run_suite build "$@" || return $?
}


pd_load__tasks=yiIap
pd_defargs__tasks=pd_registered_prefix_target_args
pd__tasks()
{
  test -n "$pd_prefixes" -o \( -n "$pd_prefix" -a -n "$pd_root" \) \
    || error "Projectdoc context expected" 1
  test -n "$1" || set -- $(pd__ls_targets tasks 2>/dev/null)
  info "Checks to run ($pd_prefixes): $*"
  pd_run_suite tasks "$@" || return $?

  #local r=0 suite=tasks
  ## TODO: pd tasks
  #echo "sh:pwd" >$arguments
  #subcmd=$suite:run pd__run || r=$?
  #test -s "$errored" -o -s "$failed" && r=1
  #pd_update_records status/$suite=$r $pd_prefixes
  #return $r
}


pd_load__show=yiap
pd_defargs__show=pd_prefix_args
pd_spc__show="[ PREFIX ]..."
# Print Pdoc record and main section of package meta file.
pd__show()
{
  while test -n "$1"
  do

    test "$dry_run" && {

      skipped "pd:show:$1"

    } || {

      note "Showing main package data for '$1'"

      pd__meta get-repo $1 | \
        jsotk.py -I json -O yaml --pretty \
        --output-prefix repositories/$1 merge - - || {
        error "decoding '$1' JSON" 1
      }

      local metaf=
      update_package "$1" || {
        note "No local package data for '$1'"
      } && {

        test -n "$metaf" || error metaf 1
        test -e "$metaf" || error $metaf 1

        jsotk.py --output-prefix package -I yaml -O yaml --pretty objectpath \
          $metaf '$.*[@.main is not None]' || {

            error "decoding '$metaf' " 1
        }
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

pd_named_set_args()
{
  local named_sets="$(pd__ls_sets | lines_to_words )"
  test -n "$1" || set -- $named_sets
  while test -n "$1"
  do
    fnmatch "* $1 *" " $named_sets " && {
      echo $1
    } || {
      error "No such named set '$1'"
    }
    shift
  done | words_to_unique_lines >>$arguments
}

# List std named set(s)
pd__ls_comp()
{
  echo "Init comp: $pd_init__sets"
  echo "Check comp: $pd_check__sets"
  echo "Test comp: $pd_test__sets"
}


# List targets for given named set(s)
pd__ls_reg()
{
  while test -n "$1"; do
    note "Targets for set '$1'"
    eval echo $(try_value sets $1) | words_to_lines
    shift
  done
}
pd_defargs__ls_reg=pd_named_set_args
pd_load__ls_reg=ia


pd_spc__ls_targets="[ NAME ]..."
# Gather targets that apply for given named set(s) (in prefix)
pd__ls_targets()
{
  test -n "$pd_prefixes" || error "pd_prefixes" 1
  local pd_prefix=
  for pd_prefix in $pd_prefixes
  do
    local name=
    while test -n "$1"
    do
      note "Named target list '$1' ($pd_prefix)"; name=$1; shift
      read_if_exists $pd_prefix/.pd-$name && continue
      (
        cd $pd_prefix
        pd_package_meta "$name" && continue
        info "Autodetect for '$name'"
        pd_autodetect $name
      )
    done
  done | words_to_lines
}
pd_defargs__ls_targets=pd_named_set_args
pd_load__ls_targets=yiapd


pd_spc__ls_auto_targets="[ NAME ]..."
# Gather targets that would apply by default for given named set(s)
pd__ls_auto_targets()
{
  while test -n "$1"
  do
    note "Returning auto targets '$1' ($pd_prefix)"
    pd_autodetect $1
    shift
  done | words_to_lines
}
pd_defargs__ls_auto_targets=pd_named_set_args
pd_load__ls_auto_targets=diap


# List all paths; -dfl or with --tasks filters
pd_load__list_paths=iO
pd__list_paths()
{
  opt_args "$@"
  set -- "$(cat $arguments)"
  req_cdir_arg "$@"
  shift 1; test -z "$@" || error surplus-arguments 1
  local find_ignores="$(find_ignores $IGNORE_GLOBFILE) $(pd__list_paths_opts)"
  # FIXME: some nice way to get these added in certain contexts
  find_ignores="-path \"*/.git\" -prune $find_ignores "
  find_ignores="-path \"*/.bzr\" -prune -o $find_ignores "
  find_ignores="-path \"*/.svn\" -prune -o $find_ignores "

  debug "Find ignores: $find_ignores"
  eval find $path $find_ignores -o -path . -o -print
}
pd__list_paths_opts()
{
  while read option; do case "$option" in
      -d ) echo "-o -not -type d " ;;
      -f ) echo "-o -not -type f " ;;
      -l ) echo "-o -not -type l " ;;
      --src )
          echo " -o -not -type f "
        ;;
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
      * ) echo "$option " ;;
    esac
  done < $options
}



pd_spc__loc='SRC-FILE...'
# Count non-empty, non-comment lines from files
pd__loc()
{
  while test -n "$1"
  do
    read_nix_style_file "$1"
    shift
  done | line_count
}


pd_load__src_report=iO
pd__src_report()
{
  pd__list_paths . --src | while read path
  do
    test -e "$path" || continue
    echo $path chars=$(count_chars $path) lines=$(count_lines $path)
    # src_loc="$(line_count $path)"
  done
}


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
pd_preload()
{
  CWD=$(pwd -P)
  test -n "$EDITOR" || EDITOR=nano
  #test -n "$P" || PATH=$CWD:$PATH
  test -n "$hostname" || hostname="$(hostname -s | tr 'A-Z' 'a-z')"
  test -n "$uname" || uname=$(uname)
  test -n "$HTD_ETC" || HTD_ETC="$(pd_init_etc | head -n 1)"
}

pd_load()
{
  sys_load
  str_load

  test -x "$(which sponge)" || warn "dep 'sponge' missing, install 'moreutils'"

  test -n "$pd" || pd=.projects.yaml

  test -n "$PD_SYNC_AGE" || export PD_SYNC_AGE=$_3HOUR

  test -n "$PD_TMPDIR" || PD_TMPDIR=$(setup_tmpd $base)
  test -n "$PD_TMPDIR" -a -d "$PD_TMPDIR" || error "PD_TMPDIR load" 1

  test -n "$UCONF" || {
    test -e $HOME/.conf \
      && UCONF=$HOME/.conf \
      || error env-UCONF 1
  }
  # FIXME: test with this enabled
  #test "$(echo $PD_TMPDIR/*)" = "$PD_TMPDIR/*" \
  #  || warn "Stale temp files $(echo $PD_TMPDIR/*)"

  ignores_load
  test -n "$PD_IGNORE" -a -e "$PD_IGNORE" || error "expected $base ignore dotfile" 1
  lst_init_ignores

  pd_inputs="arguments prefixes options"
  pd_outputs="passed skipped errored failed"

  test -n "$pd_session_id" || pd_session_id=$(get_uuid)

  SCR_SYS_SH=bash-sh

  # Selective per-subcmd init
  info "Loading '$subcmd': $(try_value "${subcmd}" load | sed 's/./&\ /g')"
  for x in $(try_value "${subcmd}" load | sed 's/./&\ /g')
  do case "$x" in

    p ) # Load/Update package meta at prefix; should imply y or d

        test -n "$prefixes" -a -s "$prefixes" \
          && pd_prefixes="$(cat $prefixes | words_to_lines )" \
          || pd_prefixes=$pd_prefix

        local pref=
        for pref in $pd_prefixes; do
          pd__meta_sq get-repo "$pref" && update_package "$pref" || continue
        done
        unset pref
      ;;

    P )
        pd__meta_sq get-repo "$pd_prefix" && {

          update_package "$pd_prefix" || { r=$?
            test  $r -eq 1 || error "update_package" $r
            continue
          }
        }

        test -e $pd_root/$pd_prefix/.package.sh \
          && eval $(cat $pd_root/$pd_prefix/.package.sh)

        test -n "$package_id" && {
          note "Found package '$package_id'"
        } || {
          trueish "$require_prefixes" && error "package_id" 1

          package_id="$(basename $(realpath $pd_prefix))"
          note "Using package ID '$package_id'"
        }
      ;;

    d ) # XXX: Stub for no Pd context?
        #test -n "$pd_root" \
        test -e "$pd" || unset pd
        test -n "$pd_prefix" || pd_prefix=.
        pd_realpath= pd_root=. pd_realdir=$(pwd -P)

        #test "$pd_prefix" = "." || {
        #  test ! -e $pd_prefix || cd $pd_prefix
        #}
      ;;

    y )
        # look for Pd Yaml and set env: pd_prefix, pd_realpath, pd_root
        # including socket path, to check for running Bg metadata proc
        req_vars pd
        test -n "$pd_root" || pd_finddoc
      ;;

    f )
        # Preset name to subcmd failed file placeholder
        # include realpath of projectdoc (p)
        test -n "$pd" && {
          export failed=$(setup_tmpf .failed -$pd_cid-$subcmd-$pd_session_id)
        } || failed=$(setup_tmpf .failed -$subcmd-$pd_session_id )
      ;;

    i )
        # TODO: replace below with setup_io_paths, but rename pd_in/outputs frst

        test -n "$pd_root" && {
          # expect Pd Context; setup IO paths (req. y)
          req_vars pd pd_cid pd_realpath pd_root || error \
            "Projectdoc context expected ($pd; $pd_cid; $pd_realpath; $pd_root)" 1

          io_id=-${pd_cid}-${subcmd}-${pd_session_id}
        } || {
          io_id=-$base-$subcmd-${pd_session_id}
        }
        fnmatch "*/*" "$io_id" && error "Illegal chars" 12
        for io_name in $pd_inputs $pd_outputs
        do
          #test -n "$(eval echo \$$io_name)" || {
            tmpname=$(setup_tmpf .$io_name $io_id)
            touch $tmpname
            eval $io_name=$tmpname
            unset tmpname io_name
          #}
        done
        export $pd_inputs $pd_outputs
      ;;

    I ) # setup IO descriptors (requires i before)
        req_vars pd pd_cid pd_realpath pd_root $pd_inputs $pd_outputs
        local fd_num=2 io_dev_path=$(io_dev_path)
        for fd_name in $pd_outputs $pd_inputs
        do
          fd_num=$(( $fd_num + 1 ))
          # TODO: only one descriptor set per proc, incl. subshell. So useless?
          test -e "$io_dev_path/$fd_num" || {
            debug "exec $(eval echo $fd_num\\\>$(eval echo \$$fd_name))"
            eval exec $fd_num\>$(eval echo \$$fd_name)
          }
        done
      ;;

    b )
        # run metadata server in background for subcmd
        pd_meta_bg_setup
      ;;

    a )
        # Set default args or filter. Value can be literal or function.
        local pd_default_args="$(eval echo "\"\$$(try_local $subcmd defargs)\"")"
        pd_default_args "$pd_default_args" "$@"
      ;;

    o )
        local pd_optsv="$(eval echo "\"\$$(try_local $subcmd optsv)\"")"
        test -s "$options" && {
          $pd_optsv
        } || noop
      ;;

    g )
        # Set default args based on file glob(s), or expand short-hand arguments
        # by looking through the globs for existing paths
        pd_trgtglob="$(eval echo "\"\$$(try_local $subcmd trgtglob)\"")"
        pd_globstar_search "$pd_trgtglob" "$@"
      ;;

  esac; done

  local tdy="$(try_value "${subcmd}" today)"
  test -z "$tdy" || {
    today=$(statusdir.sh file $tdy)
    tdate=$(date +%y%m%d0000)
    test -n "$tdate" || error "formatting date" 1
    touch -t $tdate $today
  }
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
        clean_io_lists $pd_inputs $pd_outputs
        std_io_report $pd_outputs || subcmd_result=$?
      ;;
    I )
        local fd_num=2
        for fd_name in $pd_outputs $pd_inputs
        do
          fd_num=$(( $fd_num + 1 ))
          #eval echo $fd_num\\\<\\\&-
          eval exec $fd_num\<\&-
        done
        eval unset $pd_inputs $pd_outputs
        unset pd_inputs pd_outputs
      ;;
    y )
        test -z "$pd_sock" || {
          pd_meta_bg_teardown
          unset bgd pd_sock
        }
      ;;
  esac; done

  test -n "$PD_TMPDIR" || error "PD_TMPDIR unload" 1
  # FIXME: make so everything cleans up
  #test "$(echo $PD_TMPDIR/*)" = "$PD_TMPDIR/*" \
  #  || warn "Leaving temp files $(echo $PD_TMPDIR/*)"

  unset subcmd subcmd_pref \
          def_subcmd func_exists func \
          PD_TMPDIR \
          pd_session_id

  return $subcmd_result
}

pd_init()
{
  test -z "$scriptdir" || return 13
  scriptdir="$(dirname "$(realpath "$0")")"
  export SCRIPTPATH=$scriptdir
  pd_preload || exit $?
  . $scriptdir/util.sh load-ext
  lib_load sys os std stdio str src main meta
  . $scriptdir/box.init.sh
  lib_load box
  box_run_sh_test
  # -- pd box init sentinel --
  test -n "$verbosity" && note "Verbosity at $verbosity" || verbosity=6
}

pd_init_etc()
{
  test ! -e etc/htd || echo etc
  test ! -e $(dirname $0)/etc/htd || echo $(dirname $0)/etc
  test ! -e $HOME/bin/etc/htd || echo $HOME/bin/etc
  #XXX: test ! -e .conf || echo .conf
  #test ! -e $UCONFDIR/htd || echo $UCONFDIR
}

pd_lib()
{
  test -z "$__load_lib" || return 14
  local __load_lib=1
  test -n "$scriptdir" || return 12
  lib_load box meta list match date doc table ignores
  . $scriptdir/vc.sh load-ext
  . $scriptdir/projectdir.lib.sh "$@"
  . $scriptdir/projectdir-bats.inc.sh
  . $scriptdir/projectdir-fs.inc.sh
  . $scriptdir/projectdir-git.inc.sh
  . $scriptdir/projectdir-git-versioning.inc.sh
  . $scriptdir/projectdir-grunt.inc.sh
  . $scriptdir/projectdir-npm.inc.sh
  . $scriptdir/projectdir-make.inc.sh
  . $scriptdir/projectdir-lizard.inc.sh
  . $scriptdir/projectdir-vagrant.inc.sh
  # -- pd box lib sentinel --
}


### Main

pd_main()
{
  local scriptname=projectdir scriptalias=pd base= \
    subcmd=$1 \
    base="$(basename "$0" .sh)" scriptdir=

  pd_init || exit $?

  case "$base" in

    $scriptname | $scriptalias )

        unset pd_session_id

        # invoke with function name first argument,
        local pd_session_id= bgd= \
          func_exists= \
          func= \
          pd_sock= \
          c=0 \
          ext_sh_sub= \
          base=pd

        shift $c

        pd_lib "$@" || error pd_lib $?

        try_subcmd "$@" && {

          #record_env_keys pd-subcmd pd-env

          box_src_lib pd
          shift 1

          pd_load "$@" || error "pd_load" $?

          test -z "$arguments" -o ! -s "$arguments" || {
            info "Setting $(count_lines $arguments) args to '$subcmd' from IO"
            set -f; set -- $(cat $arguments | lines_to_words) ; set +f
          }

          $subcmd_func "$@" || r=$?

          pd_unload || r=$?

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


