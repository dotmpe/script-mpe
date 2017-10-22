#!/bin/sh


# Init Bg service
pd_meta_bg_setup()
{
  test -n "$no_background" && {
    note "Forcing foreground/cleaning up background"
    test ! -e "$pd_sock" || pd__meta exit \
      || error "Exiting old" $?
  } || {
    test ! -e "$pd_sock" || error "pd meta bg already running" 1
    pd__meta &
    while test ! -e $pd_sock
    do note "Waiting for server.." ; sleep 1 ; done
    info "Backgrounded pd-meta for $pdoc (PID $!)"
  }
}

# Close Bg service
pd_meta_bg_teardown()
{
  test ! -e "$pd_sock" || {
    pd__meta exit
    while test -e $pd_sock
    do note "Waiting for background shutdown.." ; sleep 1 ; done
    info "Closed background metadata server"
    test -z "$no_background" || warn "no-background on while pd-sock existed"
  }
}

# TODO: run git clean, with ignore rules adjusted to exclude gitignore-clean
# TODO: setup some htd/pd clean. Fix htd/pd ignore setup.
# TODO: rename force_clean to pd_meta_Force_Clean or something.. --force-clean
pd_auto_clean()
{
  debug "Runing Pd auto-clean (Force-Clean: $force_clean)"
  trueish "$force_clean" && {
    ( cd $1; git clean -dfx ; git checkout . ; git submodule update --recursive )
  } || {
    ( cd $1; git clean -df )
  }
}

# Test is checkout is clean according to pd-meta Clean-Mode.
pd_clean()
{
  # Stage one, show just the modified files (always consider mode tracked)
  (cd "$1"; git diff --quiet) && {
    info "No modifications found ($1)"
  } || {
    dirty="$(cd "$1"; git diff --name-only)"
    return 1
  }

  # Stage two, show other files (consider untracked, excluded)
  test -n "$pd_meta_clean_mode" || pd_meta_clean_mode=untracked

  trueish "$choice_strict" \
    && pd_meta_clean_mode=excluded

  debug "Mode: $pd_meta_clean_mode"

  test "$pd_meta_clean_mode" = tracked || {

    #cruft="$(cd $1; vc__excluded)"

    test "$pd_meta_clean_mode" = excluded \
      && cruft="$(cd $1; vc__excluded)" \
      || cruft="$(cd $1; vc__unversioned_files)"
  }


  test -z "$cruft" || {
    trueish $choice_force && {
      ( cd "$1" ; git clean -dfx )
      warn "Force cleaned everything in $1"
    } || return 2
  }
}

# dir exist and is enabled checkout, or is not enabled
pd_check()
{
  test -d "$1" && {
    test -e "$1/.git" || {
      note "Not a checkout: $1"
      return 1
    }
    pd__meta -sq enabled $1 || {
      note "To be disabled: $1"
    }
  } || {
    pd__meta -sq enabled $1 || return 0
    note "Missing checkout: $1"
    return 1
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


# Generate/install GIT hook scripts from env (loaded from package.yaml)

test -n "$GIT_HOOK_NAMES" || GIT_HOOK_NAMES="apply-patch commit-msg post-update pre-applypatch pre-commit pre-push pre-rebase prepare-commit-msg update"

generate_git_hooks()
{
  # Create default script from pd-check
  test -n "$package_pd_meta_git_hooks_pre_commit_script" || {
    package_pd_meta_git_hooks_pre_commit_script="set -e ; pd run $package_pd_meta_check"
  }

  for script in $GIT_HOOK_NAMES
  do
    t=$(eval echo \$package_pd_meta_git_hooks_$(echo $script|tr '-' '_'))
    test -n "$t" || continue
    test -e "$t" -a "$t" -nt ".package.sh" || {
      s=$(eval echo \$package_pd_meta_git_hooks_$(echo $script|tr '-' '_')_script)
      test -n "$s" || {
        echo "No default git $script script. "
        return
      }

      mkdir -vp $(dirname $t)
      echo "$s" >$t
      chmod +x $t
      echo "Generated $script GIT commit hook"
    }
  done
}

install_git_hooks()
{
  for script in $GIT_HOOK_NAMES
  do
    t=$(eval echo \$package_pd_meta_git_hooks_$(echo $script|tr '-' '_'))
    test -n "$t" || continue
    l=.git/hooks/$script
    test ! -e "$l" || {
      test -h $l && {
        test "$(readlink $l)" = "../../$t" && continue || {
          rm $l
        }
      } ||  {
        echo "Git hook exists and is not a symlink: $l"
        continue
      }
    }
    test -d .git || error $(pwd)/.git 1
    mkdir -p .git/hooks
    ( cd .git/hooks; ln -s ../../$t $script )
    echo "Installed GIT hook symlink: $script -> $t"
  done
}

pd_regenerate()
{
  debug "pd-regenerate pwd=$(pwd) 1=$1"

  # Regenerate .git/info/exclude
  vc__regenerate "$1" || echo "pd-regenerate:$1" 1>&6

  test ! -e .package.sh || eval $(cat .package.sh)

  # Regenerate from package.yaml: GIT hooks
  set | grep -q '^package_pd_meta_git_' && {
    generate_git_hooks && install_git_hooks \
      || echo "pd-regenerate:git-hooks:$1" 1>&6
  } || noop

}


pd_package_meta()
{
  test -e .package.sh || return 1
  test -s .package.sh || return 2
  local value=
  eval $(cat .package.sh)
  while test -n "$1"
  do
    value="$(eval echo "\$package_pd_meta_$1")"
    test -n "$value" && echo "$value" || return 1
    shift
  done
}

pd_defargs__env=pd_prefix_args
pd_load__env=yiap
pd_spc__env="[ PREFIX ]..."
# Show env for prefix[es]
pd__env()
{
  test -n "$1" || set -- $pd_prefix
  for pd_prefix in $@
  do
    cd $pd_realdir/$pd_prefix

    test -n "$ENV" ||  {
      ENV=$(
          grep 'package_pd_meta_env' .package.sh 2>/dev/null | \
            sed 's/package_pd_meta_env=//g'
        )
      test -n "$ENV" || ENV=development
    }
    echo ENV=$ENV

    fnmatch "* $ENV* *" " $(pd__package_envs 2>/dev/null ) " && {
      pd__package_env $ENV
    } || {
      trueish $choice_force && {
        error "Environment '$ENV' does not apply to $pd_prefix"
        return 1
      }
    }
  done

  cd $pd_realdir
}

pd__package_env()
{
  grep 'package_environment_'$1 .package.sh | \
    sed 's/package_environment_'$1'.*__[0-9]*=//g' | sort -u
}

pd__package_envs()
{
  grep 'package_environments' .package.sh | \
    sed 's/package_environments__[0-9]*=//g' | sort -u
}



pd_list_upstream()
{
  test -n "$prefix"
  pd__meta -s list-upstream "$prefix" \
    | while read remote branch
  do
    test "$branch" != "*" && {
      echo $remote $branch
    } || {
      for branch in $(vc__list_local_branches "$prefix")
      do
        echo $remote $branch
      done
    }
  done
}

# Find and move to Pd root
pd_finddoc()
{
  # set/check for Pd for subcmd
  go_to_directory $pdoc || return $?
  test -e "$pdoc" || error "No projects file $pdoc" 1

  pd_root="$(dirname "$pdoc")"
  pd_realdir="$(realpath "$pd_root")"
  pd_realpath="$(realpath "$pdoc")"

  # Relative path to previous dir where cmd was called
  pd_prefix="$(normalize_relative "$go_to_before")"

  # Build path name based on real Pd path
  mksid "$pd_realpath"
  fnmatch "*/*" "$sid" && error "Illegal chars sid='$sid'" 11

  p="$sid"
  sock=/tmp/pd-$p-serv.sock

  pd=$pd_realdir/$pd_prefix
  pd_sid=$sid
  pd_sock=/tmp/pd-${pd_sid}-serv.sock

  debug "Pd prefix: $pd_prefix, realdir: $pd_realdir Before: $go_to_before"
  unset sid
}


pd_fetch_status()
{
  pd__meta status "$1" || return $?
}

# Update Pdoc prefix entry
pd_update_record()
{
  test -n "$1" || error "pd-update-record key-pref" 1
  test -n "$2" || error "pd-update-record key-values" 1
  test -e "$pdoc" || error "pd-update-record Pd" 1

  local path=$1; shift; local values="$*"

  { while test -n "$1"
    do
      fnmatch "/*" "$1" && {
        error "Missing relative prefix on '$1'"
        continue
      }
      echo $path/$1; shift; done
  } | jsotk.py -I pkv --pretty update $pdoc - || return $?

  debug "Updated Pd: $path{$values}"
}


# update-records key-value prefixes
pd_update_records()
{
  local kv=$1 states=
  shift
  states="$( while test -n "$1"
  do
    echo $(normalize_relative "$1")/$kv
    shift
  done )"
  pd_update_record repositories $states
}


# Built-in named sets and component available for that set
pd_sets="init check test"
pd_init__sets=
pd_check__sets=
pd_test__sets=

pd_register()
{
  local mod=$1 registry=
  shift
  while test -n "$1"
  do
    fnmatch "*$1*" "$pd_sets" || pd_sets="$pd_sets $1"
    registry="$(echo_local sets $1)"
    eval export $registry="\"\$$registry $mod\""
    shift
  done
}


# Debugging of current IO
pd_list_io_num_name_types()
{
  local num= io_type=
  set -- stdin stdout stderr $pd_outputs $pd_inputs
  note "Current IO table"
  echo "# FD NAME DIR DEVTYPE"
  list_io_nums | while read num
  do
    io_type=
    fnmatch "* $1 *" " stdin $pd_inputs " && io_type=IN
    fnmatch "* $1 *" " stdout stderr $pd_outputs " && io_type=OUT
    echo $num $1 $io_type $(get_stdio_type $num $$)
    shift
  done
}


# Debug env keys
record_env_keys()
{
  test -n "$pd_session_id" || error "pd_session_id expected" 1
  test -n "$1" || error "record_env_keys name expected" 1
  mkdir -p /tmp/env-keys

  { env; set; local; } \
    | sed 's/=.*$//' \
    | tr -d '\t ' \
    | sort -u > /tmp/env-keys/.tmp
}

record_env_keys_diff()
{
  test -n "$2" && {
    new=$1; shift;

    set -- "$(echo $@ | words_to_lines | sed 's#^#/tmp/env-keys/#g' | lines_to_words )"
    cat $@ | sort -u > /tmp/env-keys.tmp

    comm -23 /tmp/env-keys/.tmp /tmp/env-keys.tmp \
      | tr -d '\t ' \
      > /tmp/env-keys/$new
    rm /tmp/env-keys.tmp
    rm /tmp/env-keys/.tmp
  } || {
    mv /tmp/env-keys/.tmp /tmp/env-keys/$1
  }
}


# Echo debug line for target exec start; with diff of named envs + extra names
pd_debug()
{
  return # XXX:
  local debug=$1 target=$2 env_keys=$3 vars=
  shift 3
  set -- "$@" $(cat /tmp/env-keys/$env_keys | lines_to_words )
  while test -n "$1"
  do
    vars="$vars $1=$(eval echo \$$1)"
    shift
  done
  debug "$debug $target ($vars)"
}



# Pd output shortcut

# XXX: unused
pd_stdout()
{
  test -n "$1" && {
    test -z "$2" || error "pd-stdout '$2': surplus args" 1
    echo "$1" >&1
  } || {
    cat >&1
  }
}


# For patterns with one globstar, search for existing
pd_globstar_search()
{
  local pd_trgtglob="$1"
  shift
  test -n "$1" && {
    note "Getting args for '$@' ($pd_trgtglob)"
    while test -n "$1"
    do
      test -e "$1" && {
        echo $1
      } || {
        targets=$(echo "$pd_trgtglob" | sed 's#\*#'$1'#')
        for arg in $targets
        do
          test -e "$arg" && {
            echo $arg
          }
        done
      }
      shift
    done
    unset arg
  } || {
    printf -- "$pd_trgtglob"
  }
}

# Given a one-globstar pattern, return possible values of only the globstar
# part.
pd_globstar_names()
{
  local pd_trgtglob="$1"
  shift
  test -n "$1" || set -- "*"
  note "Getting names '$@' ($pd_trgtglob)"
  while test -n "$1"
  do
    set -f
    for glob in $pd_trgtglob
    do
      set +f

      local \
        gpref=$(( $(printf "$glob" | cut -f 1 -d '*' | wc -m ) + 0 )) \
        gsuff=$(( $(printf "$glob" | cut -f 2 -d '*' | wc -m ) - 1 ))
      local \
        targets=$(echo "$glob " | sed 's#\*#'$1'#')

      for target in $targets
      do
        test -e "$target" && {
          echo $target | cut -c${gpref}-$(( ${#target} - ${gsuff} ))
        }
      done

      set -f
    done
    set +f

    shift
  done
}


pd_default_args()
{
  local pd_default_args="$1"; shift
  {
    test -n "$pd_default_args" -a "$pd_default_args" != "." \
      && try_func $pd_default_args
  } && {
    $pd_default_args "$@"
  } || {
    test -z "$1" && {
      echo "$pd_default_args"
    } || {
      echo "$@"
    } | words_to_lines >$arguments
  }
}


pd_autodetect()
{
  local named_sets= targets= func= target=
  test -n "$1" || set -- $(pd__ls_sets | lines_to_words )

  while test -n "$1"; do

    targets="$(eval echo $(try_value sets $1) | words_to_lines)"

    for target in $targets; do

      func=$(echo_local $target-autoconfig $1)
      try_func $func || continue

      (
        cd $pd_realdir/$pd_prefix
        test -s .package.sh && export $(pd__env)
        $func \
          || error "target '$target' auto-config error for '$1' ($pd_prefix) " 1
      )

    done

    shift
  done
  cd $pd_realdir
}


pd_dir_args()
{
  test -n "$1" || set -- $(cat $arguments | lines_to_words )
  printf "" >$arguments
  for $a in "$@"
  do
    test -d "$a" &&
    printf -- "$a\n" >>$arguments
  done
}


pd_prefix_args()
{
  test -n "$1" || set -- $(cat $arguments | lines_to_words )
  printf "" >$arguments
  pd_prefix_filter_args $@
  test ! -s "$arguments" || {
    error "Illegal arguments $(cat $arguments | lines_to_words)" 1
  }
  cat $prefixes > $arguments
}


# Set default value/pattern, and filter out non-dirs from arguments
pd_prefix_filter_args()
{
  test -n "$1" || set -- $(cat $arguments | lines_to_words )
  printf "" >$arguments # truncate

  # given we have a Pdoc, expand any arguments as prefixes
  test -n "$1" || {
    test "." = "$go_to_before" && {
      set -- '*' # default arg if within pd_root
    } || {
      set -- "." # default arg in subdir
    }; }

  while test -n "$1"
  do
    for expanded_arg in $(echo $go_to_before/$1)
    do
      test -d "$expanded_arg" || {
        test -e "$expanded_arg" || echo "$expanded_arg" >>$arguments
        continue
      }
      strip_trail=1 normalize_relative $expanded_arg
    done
    shift
  done \
    | words_to_unique_lines >$prefixes
}


# Filter out options and states from any given prefixes, or check enabled
pd_registered_prefix_target_args()
{
# FIXME: quoting possible?
  #set -- $(while test -n "$1"
  #do
  #  #case "$1" in --registered ) ;; esac
  #  fnmatch "-*" "$1" && echo "$1" >>$options || printf "\"$1\" "
  #  shift
  #done)
  test -n "$choice_reg" || choice_reg=1
  pd_prefix_target_args "$@" || return $?
}

# Filter states, and either expand to enabled prefixes or found prefixes
pd_prefix_target_args()
{
  test -n "$choice_reg" || choice_reg=0
  local states=""
  while test -n "$1"
  do
    fnmatch "*:*" "$1" && {
      states="$states $1"
    } || {
      echo "$1" >>$arguments
    }
    shift
  done

  stderr debug "choice-reg: $choice_reg"
  trueish "$choice_reg" && {

    # Mixin enabled prefixes with existing dirs for default args,
    # or scan for any registered prefix args iso stat existing dirs only
    #pd__meta list-disabled "$1" > $PD_TMPDIR/prefix-disabled.list
    #pd__meta list-enabled "$1" > $PD_TMPDIR/prefix-enabled.list
    #rm $PD_TMPDIR/prefix-*.list

    test -n "$1" || set -- $(cat $arguments | lines_to_words )
    printf "" >$arguments # truncate

    test -z "$1" && set -- "$go_to_before"

    while test -n "$1"
    do
      pd_prefix_arg="$(normalize_relative $1)"
      shift
      test "$pd_prefix_arg" = "." && pd_prefix_arg=
      pd__meta list-enabled "$pd_prefix_arg" | read_nix_style_file >> $prefixes
    done

  } || {

    # Stat only, don't check on (enabled) Pdoc prefixes

    # Set default or expand prefix arguments (globbing)
    pd_prefix_filter_args
  }

  # Add prefiltered states to arguments
  echo $states | words_to_unique_lines >> $arguments
}


pd_options_v()
{
  set -- "$(cat $options)"
  while test -n "$1"
  do
    case "$1" in
      --stm-yaml ) format_stm_yaml=1 ;;
      --yaml ) format_yaml=1 ;;
      * ) error "unknown option '$1'" 1 ;;
    esac
    shift
  done
}



# Execute external check/test/build scripts and track associated states
pd_run()
{
  test -n "$1" || error args 1

    fnmatch ":*" "$1" && {
      set -- "$base$1"
    } || {
      fnmatch "-*" "$1" || {
        fnmatch "sh*" "$1" || {
          set -- "sh:$1"
        }
      }
    }

  test -z "$2" || error "surplus args '$*'" 1

  note "Pd Run '$1'"

  case "$1" in

    ## Built in targets

    -* )
        note "Ignore ($1)"
        # Ignore return
        # backup $failed
        mv $errored $errored.ignore
        mv $failed $failed.ignore
        touch $failed $errored
        (
          pd_run $(expr_substr ${1} 2 ${#1}) || noop
          clean_failed "*IGNORED* Failed targets:"
        )
        mv $errored.ignore $errored
        mv $failed.ignore $failed
        result=0
      ;;

    # Shell exec

    sh:* )
        # NOTE: pd run sh automatically accepts env decl. beacuse 's/:/ /g'
        local shcmd="$(echo "$1" | cut -c 4- | tr ':' ' ')"
        record_key=$(printf "$1" | cut -d ':' -f 2 )
        info "Running Sh '$shcmd' ($1)"
        (
          unset $pd_inputs $pd_inputs
          export \
            base= func_name= func_exists= subcmd_func= \
            verbosity= pd_inputs= pd_outputs= pd_session_id= subcmd=

          sh -c "$shcmd"
          # XXX:
          #{
          #  cd "$pd_realdir"
          #  key_pref=repositories/$(normalize_relative \
          #    "$pd_prefix")/status/$record_key
          #  echo pd_update_record \
          #    result=$result
          #  pd_update_record \
          #    result=$result
          #}
        ) && result=0 || { result=$?; echo $1 >>$failed; }
      ;;

    ## Other built-ins

    #pd:*:* )
    #    info "Running Pd '$cmd' ($1)"
    #  ;;

    pd:* )

        local comp="$(echo "$1" | cut -d ':' -f 2)" ncomp=
        local comp_idx=2 func= args=
        local comp_env=

        # Phase 1: read env/comp-name from $1

        # Consume env kv's
        while true
        do
          ncomp="$(echo "$1" | cut -d ':' -f $comp_idx)"
          test -n "$ncomp" || break
          fnmatch "*=*" "$ncomp" || break
          comp_env="$comp_env $ncomp"
          comp_idx=$(( $comp_idx + 1 ))
          comp="$(echo "$1" | cut -d ':' -f $comp_idx)"
        done

        # Consume components and look for local function
        while true
        do
          # Resolve aliases
          while true
          do
            als=$(echo_local $comp als)
            var_isset $als || break
            comp=$(try_value $comp als)
          done

          func=$(echo_local $comp "")

          comp_idx=$(( $comp_idx + 1 ))
          ncomp="$(echo "$1" | cut -d ':' -f $comp_idx)"
          test -n "$ncomp" || {
            break
          }

          try_func "$func" && {
            try_func $(echo_local $comp:$ncomp "") || break
          }

          comp="$comp:$ncomp"

        done

        test -n "$comp_env" && {
          args="$(echo "$1" | cut -c$(( 5 + ${#comp_env} + ${#comp} ))-)"
        } || {
          args="$(echo "$1" | cut -c$(( 5 + ${#comp} ))-)"
        }


        # Phase 2: exec. comp func in new env

        try_func "$func" || {
          error "No such Pd target '$comp'"; echo "$1" >>$errored; return 1
        }

        sub_session_id=$(get_uuid)
        (
          unset verbosity
          subcmd="$pd_prefix#$comp"

          record_key="$(eval echo "\"\$$(echo_local "$comp" stat)\"")"
          test -n "$record_key" \
            || record_key=$(printf "$comp" | tr -c 'a-zA-Z0-9-' '/')
          states= values=

          local pd_session_id=$sub_session_id
          eval local $(for io_name in $pd_inputs $pd_outputs; do
            printf -- " $io_name= "; done) $comp_env

          subcmd=$comp pd_load "$args" || {
            error "Pd-load failed for '$1'"; echo "$1" >>$errored; return 1
          }
          test -e "$arguments" || {
            test -n "$args" || echo "$args" >$arguments
          }

          test -s $arguments || echo "$args" >$arguments

          $func "$(cat $arguments)" && result=0 \
            || { result=$?; echo $1 >>$failed; }

          {
            cd "$pd_realdir"
            info "Updating Pdoc $pd_prefix"

            # Update status result
            test -n "$states" && {
              pd_update_record $key_pref/status/$record_key $states \
                || error "Failed updating $key_pref/status/$record_key" 11
            } || {
              jsotk.py -q path --is-new --is-int $pdoc $key_pref/status/$record_key \
                || record_key=$record_key/result
              pd_update_record $key_pref/status $record_key=$result \
                || error "Failed updating $key_pref/status/$record_key" 12
            }

            # Update benchmark values
            test -z "$values" \
              || {
                pd_update_record $key_pref/benchmarks/$record_key $values \
                  || error "Failed updating $key_pref/benchmarks/$record_key" 11
              }
          }
        )

        for io_name in $pd_outputs; do
          out=$(try_var ${io_name})
          test ! -e $(setup_tmpd)/pd-*$sub_session_id.$io_name || {
            cat $(setup_tmpd)/pd-*$sub_session_id.$io_name >> $out
            rm $(setup_tmpd)/pd-*$sub_session_id.$io_name
          }
        done
        for io_name in $pd_inputs; do
          test ! -e $(setup_tmpd)/pd-*$sub_session_id.$io_name \
            || rm $(setup_tmpd)/pd-*$sub_session_id.$io_name
        done
      ;;


    * )
        error "No such run target '$1'"
        echo $1 >>$errored
      ;;

  esac
}


pd_run_suite()
{
  test -n "$1" || error "pd-run-suite: Suite ID expected" 1
  local r=0 suite=$1; shift
  echo "$@" >$arguments
  subcmd=$suite:run pd__run || return $?
  test -s "$errored" -o -s "$failed" && r=1
  pd_update_records status/$suite=$r $pd_prefixes
  return $r
}


# TODO: duplicate from htd_find_ignores, while further devving
pd_find_ignores()
{
  test -z "$find_ignores" || return
  test -n "$IGNORE_GLOBFILE" -a -e "$IGNORE_GLOBFILE" && {
    #mv $a.merged $a.tmp
    #sort -u $a.tmp > $a.merged
    find_ignores="$(find_ignores $IGNORE_GLOBFILE)"
  } || warn "Missing or empty IGNORE_GLOBFILE '$IGNORE_GLOBFILE'"

  find_ignores="-path \"*/.git\" -prune $find_ignores "
  find_ignores="-path \"*/.bzr\" -prune -o $find_ignores "
  find_ignores="-path \"*/.svn\" -prune -o $find_ignores "
}


pd_new_package()
{
  { cat <<EOM

- type: application/vnd.dotmpe.project
  main: local/$(basename $pd_prefix)
  id: local/$(basename $pd_prefix)
  scripts:
    status: pd status
    test: pd test
    pd-update: pd update
    pd-show: pd show

EOM
  } > $1/package.yml
}


