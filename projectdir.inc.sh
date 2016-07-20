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
    info "Backgrounded pd-meta for $pd (PID $!)"
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

pd_clean()
{
  # Stage one, show just the modified files
  (cd "$1"; git diff --quiet) || {
    dirty="$(cd "$1"; git diff --name-only)"
    return 1
  }

  # Stage two, show files after check for repo-clean mode (tracked, untracked, excluded)
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
    package_pd_meta_git_hooks_pre_commit_script="set -e ; pd check $package_pd_meta_check"
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
			} ||	{
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
  }

}


pd_package_meta()
{
  test -e .package.sh || return 1
  local value=
  . .package.sh
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
    sed 's/package_environment_'$1'.*__[0-9]*=//g'
}

pd__package_envs()
{
  grep 'package_environments' .package.sh | \
    sed 's/package_environments__[0-9]*=//g'
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
  go_to_directory $pd || return $?
  test -e "$pd" || error "No projects file $pd" 1

  pd_root="$(dirname "$pd")"
  pd_realdir="$(realpath "$pd_root")"
  pd_realpath="$(realpath "$pd")"

  # Relative path to previous dir where cmd was called
  pd_prefix=$go_to_before

  # Build path name based on real Pd path
  mkcid "$pd_realpath"
  fnmatch "*/*" "$cid" && error "Illegal chars cid='$cid'" 11

  p="$cid"
  sock=/tmp/pd-$p-serv.sock

  pd_cid=$cid
  pd_sock=/tmp/pd-${pd_cid}-serv.sock

  debug "Pd prefix: $pd_prefix, realdir: $pd_realdir Before: $go_to_before"
  unset cid
}


# Update Pdoc status entry
pd_update_status()
{
  test -e "$pd" || error "pd-update-status Pd" 1
  test -n "$key_pref" || error "pd-update-status key-pref" 1

  { while test -n "$1"
    do
      fnmatch "/*" "$1" && {
        error "Missing relative prefix on '$1'"
        continue
      }
      echo $key_pref/$1; shift; done
  } | jsotk.py -I pkv --pretty update $pd - || return $?

  debug "Updated Pd: $key_pref{$*}"
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
    registry="$(try_local sets $1)"
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
  test -n "$1" || error record_env_keys 1

  mkdir -p /tmp/env-keys
  { env; set; local; } \
    | sed 's/=.*$//' \
    | tr -d '\t ' \
    | sort -u > /tmp/env-keys/.tmp

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


pd_report()
{
  # leave pd_report_result to "highest" set value (where 1 is highest)
  pd_report_result=0

  while test -n "$1"
  do
    case "$1" in

      passed )
          test $passed_count -gt 0 \
            && info "Passed ($passed_count): $passed_abbrev"
        ;;

      skipped )
          test $skipped_count -gt 0 \
            && {
              note "Skipped ($skipped_count): $skipped_abbrev"
              test $pd_report_result -eq 0 -o $pd_report_result -gt 4 \
                && pd_report_result=4
            }
        ;;

      error )
          test $error_count -gt 0 \
            && {
              error "Errors ($error_count): $error_abbrev"
              test $pd_report_result -eq 0 -o $pd_report_result -gt 2 \
                && pd_report_result=2
            }
        ;;

      failed )
          test $failed_count -gt 0 \
            && {
              warn "Failed ($failed_count): $failed_abbrev"
              test $pd_report_result -eq 0 -o $pd_report_result -gt 3 \
                && pd_report_result=3
            }
        ;;

      * )
        ;;

    esac
    shift
  done

  return $pd_report_result
}


# Pd output shortcuts

pd_stdout()
{
  test -n "$1" && {
    test -z "$2" || error "passed surplus args" 1
    echo "$1" >&1
  } || {
    cat >&1
  }
}
passed()
{
  test -n "$1" && {
    test -z "$2" || error "passed surplus args" 1
    echo "$1" >&3
  } || {
    cat >&3
  }
}
skipped()
{
  test -n "$1" && {
    test -z "$2" || error "skipped surplus args" 1
    echo "$1" >&4
  } || {
    cat >&4
  }
}
errored()
{
  test -n "$1" && {
    test -z "$2" || error "errored surplus args" 1
    echo "$1" >&5
  } || {
    cat >&5
  }
}
failed()
{
  test -n "$1" && {
    test -z "$2" || error "failed surplus args" 1
    echo "$1" >&6
  } || {
    cat >&6
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
  try_func $pd_default_args && {
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

      func=$(try_local $target-autoconfig $1)
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


pd_prefix_args()
{
  test -n "$1" || set -- $(cat $arguments | lines_to_words )
  printf "" >$arguments
  pd_prefix_filter_args "$@"
  test ! -s "$arguments" || {
    error "Illegal arguments $(cat $arguments | lines_to_words)" 1
  }
  cat $prefixes > $arguments
}


# Set default value/pattern, and filter out non-dirs from arguments
pd_prefix_filter_args()
{
  test -n "$1" || set -- $(cat $arguments | lines_to_words )
  printf "" >$arguments

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


pd_prefix_target_args()
{
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

  # Set default or expand prefix arguments
  pd_prefix_filter_args

  # Add prefiltered states to arguments
  echo $states | words_to_unique_lines >> $arguments
}


# Execute external check/test/build scripts and track associated states
pd_run()
{
  test -n "$1" || error args 1

  fnmatch ":*" "$1" && set -- "$(echo "$1" | cut -c2-)"
  fnmatch "*:*:*" "$1" || set -- "$base:$1"
  fnmatch "*:*" "$1" || set -- "sh:$1"

  test -z "$2" || error "surplus args '$*'" 1

  note "Pd Run '$1'"

  case "$1" in

    ## Built in targets

    -* )
        note "Ignore ($1)"
        # Ignore return
        # backup $failed
        mv $failed $failed.ignore
        touch $failed
        (
          pd_run $(expr_substr ${1} 2 ${#1}) || noop
          clean_failed "*IGNORED* Failed targets:"
        )
        mv $failed.ignore $failed
      ;;

    # Shell exec

    sh:* )
        local shcmd="$(echo "$1" | cut -c 4- | tr ':' ' ')"
        status_key=$(printf "$1" | cut -d ':' -f 2 )
        info "Running Sh '$shcmd' ($1)"
        (
          sh -c "$shcmd" \
            && result=0 || { result=$?; echo $1 >>$failed; }
          {
            cd "$pd_realdir"
            key_pref=repositories/$(normalize_relative \
              "$pd_prefix")/status/$status_key
            pd_update_status \
              result=$result
          }
        )
      ;;

    ## Other built-ins

    #pd:*:* )
    #    info "Running Pd '$cmd' ($1)"
    #  ;;

    pd:* )

        local comp=$(echo "$1" | cut -d ':' -f 2) ncomp=
        local comp_idx=2 func= args=$(echo "$1" | cut -c$(( 5 + ${#comp} ))-)


        # Consume components and look for local function
        while true
        do
          # Resolve aliases
          while true
          do
            als=$(try_local $comp als)
            var_isset $als || break
            comp=$(try_value $comp als)
          done

          func=$(try_local $comp "")

          comp_idx=$(( $comp_idx + 1 ))
          ncomp="$(echo "$1" | cut -d ':' -f $comp_idx)"
          test -n "$ncomp" || {
            break
          }
          args="$(echo "$args" | cut -c$(( 2 + ${#ncomp} ))-)"

          try_func "$func" && {
            try_func $(try_local $comp:$ncomp "") || break
          }

          comp="$comp:$ncomp"

        done

        try_func "$func" || {
            error "No such Pd target '$comp'"; echo "$1" >>$error; return 1
          }

        sub_session_id=$(uuidgen)

        (
          subcmd="$pd_prefix#$comp"

          status_key="$(eval echo "\"\$$(try_local "$comp" stat)\"")"
          test -n "$status_key" \
            || status_key=$(printf "$comp" | tr -c 'a-zA-Z0-9-' '/')
          states=

          local pd_session_id=$sub_session_id
          eval local $(for io_name in $pd_inputs $pd_outputs; do
            printf -- " $io_name= "; done)

          subcmd=$comp pd_load "$args" || {
            error "Pd-load failed for '$1'"; echo "$1" >>$error; return 1
          }

          test -s $arguments || echo "$args" >$arguments

          $func "$(cat $arguments)" && result=0 \
            || { result=$?; echo $1 >>$failed; }

          {
            cd "$pd_realdir"
            key_pref=repositories/$(normalize_relative \
              "$pd_prefix")/status/$status_key
            pd_update_status \
              result=$result \
              $states
          }
        )

        for io_name in $pd_outputs; do
          out=${!io_name}
          cat $(setup_tmpd)/pd-*$sub_session_id.$io_name >> $out
          rm $(setup_tmpd)/pd-*$sub_session_id.$io_name
        done
        for io_name in $pd_inputs; do
          rm $(setup_tmpd)/pd-*$sub_session_id.$io_name
        done
      ;;


    * )
        error "No such run target '$1'"
        echo $1 >>$error
      ;;

  esac
}


