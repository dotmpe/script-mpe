#!/bin/sh

# Project Test Scripts tooling wip


# Initialize Project Test Script shell modules
build_test_lib_load()
{
  lib_load build-htd build-checks
}

# Initialize build-test settings, set Test-Specs
build_test_init() # Specs...
{
  test -n "$base" || base=build-test.lib
  test -n "$build_init" || build_init

  # Set function to retrieve test paths/names (all or those for given component)
  test -n "$component_tests" || component_tests=component_testnames

  # Set function to resolve test path/name runner and execute
  test -n "$component_test" || component_test=component_test_exec

  # Set functions to run after test pass/fail/error/bail, or for components
  # without any test
  test -n "$project_test_ok" || project_test_ok=project_test_ok
  test -n "$project_test_nok" || project_test_nok=project_test_nok
  test -n "$project_test_error" || project_test_error=project_test_error
  test -n "$project_test_none" || project_test_none=project_test_none
  # Bail covers skipped and TODO tagged tests, but does not indicate error
  test -n "$project_test_bail" || project_test_bail=project_test_bail
  # Process files before adding to stage, or comitting. These should return 0
  # so can be used to abort git add/update or commit. (XXX: except there is no
  # pre-add or pre-update hook afaik so that only works through the build
  # scripts)

  # XXX: TDD, lists, built-init

  test -n "$project_watch_mode" || project_watch_mode=
  test -n "$default_watch_poll_sleep" || default_watch_poll_sleep=5

  case "$component_map" in component_map_list )
      test -n "$component_map_list" || component_map_list=$PWD/test-map.list
  ;; esac
  test -n "$component_map" || component_map=component_map_basenameid

  test -n "$package_build_unit_spec" || # XXX: renamed.
      package_specs_units=$package_build_unit_spec
  test -n "$package_specs_units" ||
      package_specs_units="test/py/\${id}.py test/\${id}-lib-spec.bats \
                           test/\${id}-spec.bats test/\${id}.bats"
  test -n "$package_specs_features" || package_specs_features='${1}.feature'
  test -n "$package_specs_tests_other" || package_specs_tests_other='${1}.do'

  test -n "$package_specs_baselines" ||
      package_specs_baselines="test/\${id}-baseline.*"

  test -n "$package_specs_tests_other" ||
      package_specs_tests_other="test/\${1}.do"

  test -n "$package_specs_ignore" ||
      package_specs_ignore='*/_[a-z]* _[a-z]*'

  # Enable BATS 'load' helper
  . $HOME/bin/test/init.bash
  load_init
  BATS_LIB_PATH=$BATS_LIB_PATH:$HOME/bin/test:$HOME/bin/test/helper

  build_test_init=ok
}

# FIXME: var. specsets
build_testsuite_init()
{
  # watch_flags=" -w test/bootstrap/FeatureContext.php "

  #env | grep -i 'specs.*='
  #echo '----------'
  #set | grep -i 'specs.*='
  #echo '----------'

  return
  test -z "$1" || SPECS="$@"
  test -n "$SPECS" || SPECS='*'

  #project_tests $SPECS | sort -u >"$suite"
  BATS_SUITE="$( grep '\.bats$' $suite | lines_to_words )"
}

before_test()
{
  verbose=1 git-versioning check &&
  projectdir.sh run :bats:specs
  #lib_load build-checks && check_clean test
}

tap2junit()
{
  perl $(which tap-to-junit-xml) --input $1 --output $2
}

# Map source file to suite name/source
component_map_list() # SRC-FILE
{
  test -e "$1" || error "Source-File expected '$1'" 1
  match_grep_pattern_test "$1" || return 1
  suites=$(ggrep -E \
      -e '^.* -- (.* )?\<'"$p_"'\>( .*)?$' \
      -e '^[^ ]* (.* )?\<'"$p_"'\>( .*)? -- .*$' \
    "$component_map_list" | gsed -E '
        s/^([^ ]+) .* -- (.* )?'"$p_"'( .*)?$/\1/g
        s/^([^ ]+) (.* )?'"$p_"'( .*)? -- .*$/\1/g
    ')
  test -n "$suites" || return 1

  for suite_id in $suites
  do
      note "Suite: '$suite_id' src: $1"
      fnmatch "*+*" "$suite_id" && {
        suite_id="$(echo "$suite_id" | cut -d'+' -f1)"
        tag_id="$(echo "$suite_id" | cut -d'+' -f2-)"
      }
      echo "$suite_id $1"
  done
}

# Give up TEST-FILES for suite
component_map_tests() # SUITE-ID
{
  set -- "$(compile_glob "$1")"
  ggrep '^'"$1"' .* -- .*$' "$component_map_list" |
      gsed 's#^'"$1"'\ \(.*\) -- .*$#\1#g'
}

test_scm() # LIST [UPDATE]
{
  test -n "$2" && {
    func_exists "$2" && update=$2 || error "Function '$2' expected" 1
  } || {
    git_add() { local base=$1 ; shift ; git add "$@" ; }
    update=git_add
  }

  test_run "$1" "$update"
}

test_shells()
{
  test -n "$shells" || shells='bash sh dash zsh ksh posh' # heirloom-sh fish yash'

  for sh in $shells
  do
    note "Starting in '$sh' shell '$*'"
    test -x "$(which $sh)" && {
      $sh -c "$@" || return
    } || {
      docker run --workdir /dut -v $(pwd):/dut dotmpe/treebox:dev \
        $sh -c "$@" || return
    }
  done
}

#
test_lists() # TOTEST TESTED
{
  true
}

# Wrapper for project-tests/project-test.
# Given LIST file or function to list src-files, find test-files and execute
# when tests are found. If tests succeed, call update or add the paths to UPDATE.
test_run() # LIST [UPDATE]
{
  test -n "$failed" || get_tmpio_env failed test-run
  test -n "$testruns" || get_tmpio_env testruns test-run

  { func_exists "$1" && {
    "$@"
  } || {
    cat "$1"
  };} | p= s= act=$component_map foreach_do | sort -u | join_lines |
    while read -r bn paths
  do
    test -n "$paths" || {
      warn "No src-files covered by spec '$bn'"
      continue
    }

    #redo $cllct_test_base/$bn.tap
    #project_test "$bn" || touch "$failed"
    #project_tests "$@" | p='' s='' act=$component_test foreach_do

    test "$(count_lines "$testruns")" = "0" && {
      warn "No tests for $bn, no coverage for '$paths'"
      echo "test-scm:untested:$bn" >>"$failed"

    } || {
      check_clean $paths || {
        warn "Files dirty for $bn, no update"
        #echo "test-scm:dirty:$bn:$(grep_dirt $paths | words_to_lines)" >>"$failed"
      }
    }

    test -e "$failed" && {
      warn "Failed: $( lines_to_words "$failed" )"
      rm "$failed"
    } || {
      note "Updating <$paths> as $bn tests OK"
      func_exists "$2" && { $2 $bn $paths; } || {
        # NOTE: after resolving "$@" we don't know how to update $1 if a file.
        # should specify list/update routines. If both $1/$2 are a file, we
        # could simply add basename (the "suite-id") and the associated paths
        # to it, but doesn't really needs whats from/in $1?
        #test -e "$2" && echo "$paths"
          #line= grep $2
          #file_truncate_lines "$1"
        true
      }
    }
  done
}

# Execute command after paths (on stdin) are modified and don't complete run.
exec_watch_paths() # CMD
{
  local watch_flags= cmd=
  watch_flags="$(sed 's/^/-w /g' | lines_to_words)"
  note "flags: '$watch_flags'"
  test -n "$watch_flags" || error "Nothing to watch" 1
  cmd="$(echo "$@")"
  test -n "$cmd" || error "No command given" 1
  nodemon $watch_flags -x "$cmd"
}

# Simple loop to CMD if TEST evaluates OK. Then sleep poll-time, re-check.
exec_watch_poll() # TEST CMD...
{
  test -n "$poll_sleep" || poll_sleep=$default_watch_poll_sleep
  local test=$1 ; shift 1
  std_info "Run '$*' if $test evaluates OK; sleep $poll_sleep, and restart"
  while true
  do
    eval $test && {
        note "Starting run '$*'..."
        "$@" || warn "Status: $?"
    }
    sleep $poll_sleep
  done
}

# Run over paths, check wether any was modified later than PATHLIST itself was.
# Worse case stat each file and return 1.
check_pathlist_modified() # PATHLIST [TIMESTAMP]
{
  test -n "$2" || set -- "$1" "$( filemtime "$1" )"
  while read -r filepath
  do
    test "$filepath" -ot "$1" && continue || {
      echo "Changed: $( filemtime "$filepath" ) $2 $filepath"
      return 0
    }
  done < "$1"
  return 1
}

# Watch files in LIST by polling then execute CMD. See exec-watch-poll for the
# loop, and check-pathlist-modified for the polling test function. If LIST is a
# function, use it to retrieve the PATHLIST, and update this again after each
# run. Else LIST is a normal static file, or empty/'-' for stdin.
#
# E.g. to build a list of modified files (executing "$@" for every item)
#
#   vc_modified | exec_watch_poll_pathlist - "$@"
#
exec_watch_poll_pathlist() # LIST CMD CMD-ARG...
{
  local LIST=$1 watchme= ; shift

  test -e "$LIST" -o -z "$LIST" -o "$LIST" = "-" && {
    test -z "$LIST" -o "$LIST" = "-" && {
        watchme=$(setup_tmpf .watchme)
        cat | remove_dupes >"$watchme"
      } || watchme="$LIST"
    relist() { touch "$watchme"; }
  } || {
    func_exists "$LIST" || error "Function '$LIST' expected" 1
    watchme=$(setup_tmpf .watchme)
    relist() {
        $LIST >"$watchme";
        test $verbosity -le 8 || cat "$watchme";
        note "Watching $(count_lines "$watchme") paths"; }
  }

  local cmdname="$1" ; shift ; set -- "$cmdname" "$watchme" "$@"

  check() { test "$1" -ot "$watchme"; }
  check_watchlist_mtimes() { check_pathlist_modified "$watchme"; }
  run_and_relist() { ret=; exec_arg "$@" || ret=$?; relist;
      test -z "$ret" || warn "exec-watch-poll-pathlist:inner '$*': $ret"
      return $ret; }

  relist &&
  exec_watch_poll check_watchlist_mtimes run_and_relist "$@" &&
  rm "$watchme"
}

# Execute CMD if any modified file changes again, or if the GIT stage changes.
# After each run, update monitored file list and wait for next change. The
# default CMD test_scm looks for and executes tests.
exec_watch_scm() # CMD
{
  test -n "$1" || { test -z "$*" || shift; set -- test_scm "$@"; }
  exec_watch_scm_paths()
  {
     vc_modified | sort_mtimes
     # echo .git/index
  }
  exec_watch_poll_pathlist exec_watch_scm_paths "$@"
}

# Execute CMD if any
exec_watch_list() # CMD [TEST-ID...]
{
  test -n "$1" || { test -z "$*" || shift; set -- test_lists "$@"; }
  pathlist()
  { true
  }
  exec_watch_poll_pathlist pathlist "$@"
}

# Run tests for DUT's
project_test() # [Units...|Comps..]
{
  test -n "$base" || error "project-test: base required" 1

  test -n "$build_init" || build_init
  test -n "$1" || {
    set -- '*' && build_test_init "$@"
  }
  test -n "$testruns" || get_tmpio_env testruns test-run

  std_info "Starting project-test: '$component_test' for '$*'"

  p='' s='' act=$component_tests foreach_do "$@" |
      p='' s='' act=$component_test foreach_do

  test -e "$failed" && {
    test ! -s "$failed" || {
      warn "Failed components:"
      cat $failed
    }
    rm "$failed"
    return 1
  }
  note "Project test completed succesfully"
}

# Implement running each unittest variant
component_test_exec() # Test-Files...
{
  test -n "$testruns" || get_tmpio_env "testruns" "test-run"
  test $# -gt 0 || return
  while test $# -gt 0
  do
    note "Running test '$1'..."
    case "$1" in

        *.feature )
            std_info "Feature: '$TEST_FEATURE' -- '$1'"
            eval $TEST_FEATURE "$1"
            #component_set_status "$testruns" "$1" "$?"
          ;;

        *.py )
            std_info "Unit: python script '$1'"
            python "$1"
            #component_set_status "$testruns" "$1" "$?"
          ;;

        *.bats )
            std_info "Unit: bats '$1'"
            bats "$1"
            #component_set_status "$testruns" "$1" "$?"
            #test "$(get_stdio_type)" = "t" && {
            #  $TAP_COLORIZE
            #} || {
            #  cat
            #}
          ;;

        *.do )
            std_info "Redo script '$1'"
            redo "$(basename "$1" .do)"
            #component_set_status "$testruns" "$1" "$?"
          ;;

        * ) warn "Unrecognized DUT '$1'"
            #component_set_status "$testruns" "$1" "-"
          ;;
    esac || true
    shift
  done
}

# Record status
component_set_status() # Tab Entry-Id Stat
{
  stattab_entry_exists "$2" "$1" && {
    stattab_entry "$2"  "$1"
  } || {
    stattab_append
  }
}

# TODO: cleanup test-any-feature
test_any_feature()
{
  test -n "$TEST_FEATURE" || error "Test-Feature env required" 1
  std_info "Test any feature '$*'"
  test -n "$1" && {

    #local features="$(any_feature "$@" | tr '\n' ' ')"
    #test -n "$features" || error "getting features '$@'" 1
    #note "Features: $features"

    eval $TEST_FEATURE "$@" || return $?;
  } || {

    $TEST_FEATURE || return $?;
  }
}

# Echo test file names
project_tests() # [Units..|Comps..]
{
  test -n "$*" || return
  note "Listing test-files for '$*'"

  #test -n "$build_init" || build_test_init "$@"
  p='' s='' act=$component_tests foreach_do "$@"
}

component_depnames()
{
  for comp_type in script_libs scripts
  do
    test -n "$*" && {
      any_component "$comp_type" "$@" || continue
    } || {
      expand_spec_src "$comp_type" || continue
    }
  done
}

# Looking unit- or spec-test filename(s) for given src, or check if given src
# is one. To
component_testnames()
{
  for comp_type in baselines units features smoketests tests_other
  do
    test -n "$*" && {
      any_component "$comp_type" "$@" || continue
    } || {
      expand_spec_src "$comp_type" || continue
    }
  done
}

# If given component Id expands to existing path, echo. Component SPEC uses
# either $1, or $sid/vid extracted from $1.
any_component() # Spec-Set Comp-Id...
{
  test -n "$1" || return
  local id= sid= vid= spec= filter_from=
  filter_from="$cllct_set_base/$1.excludes"
  build_redo "$filter_from"
  _c="$1"; spec=$( show_spec "$1" ) ; shift
  while test $# -gt 0
  do
    mkid "$1" "" "-_*"; mksid "$1" ; mkvid "$1"
    std_info "Looking for $_c component '$1' '$id' '$sid' '$vid'"
    for x in $spec
    do
      x="$(eval echo $x)"
      test -e "$x" || continue
      echo "$x"
    done
    shift
  done | { test -s "$filter_from" && $ggrep -vf "$filter_from" || cat ; }
}

# TODO: revise test specset setup

redo_deps()
{
  lib_load redo &&
  redo_deps "$@"
}

tested()
{
  local out=$1
  test -n "$out" || out=tested.list
  read_nix_style_file $out
}

totest()
{
  local in=$1 out=$2 ; shift 2
  test -n "$in" || in=totest.list
  test -n "$out" || out=tested.list
  comm -2 -3 $in $out
}

build_test()
{
  test -n "$testruns" || get_tmpio_env "testruns" "build-test"
  $component_tests "$@" | p='' s='' act=$component_test foreach_do
}

## Specs for report but not counting in final test-result judgement

#req_vars TEST_SPECS || \
#  export TEST_SPECS="statusdir htd basename-reg dckr lst"\
#" rsr edl vc match schema table"\
#" jsotk-py jsotk-xml libcmd_stacked mimereg radical"\
#" meta pd disk diskdoc py-lib-1"

#test -n "$ProjectTest_BATS_Specs" || export ProjectTest_BATS_Specs="tests/bats/{,*-}spec.bats"

baselines()
{
  $component_test $( expand_spec_src baselines )
}

units()
{
  $component_test $( expand_spec_src units )
}

features()
{
  $component_test $( expand_spec_src features )
}

other_tests()
{
  $component_test $( expand_spec_src other_tests )
}

required_tests()
{
  $component_test $( $component_tests $package_specs_required )
}

retest()
{
  local in= out= #$1 out=$2 ; shift 2
  test -n "$in" || in=totest.list
  test -n "$out" || out=tested.list
  test -e "$in" || touch totest.list
  test -e "$out" || touch tested.list
  test -s "$in" || {
    project_tests "$@" | sort_mtimes > "$in"
  }

  while true
  do
    # TODO: do-test with lst watch
    read_nix_style_file "$in" | while read test
    do
      grep -qF "$test" "$out" && continue
      note "Running '$test'... ($(( $(count_lines "$in") - $(count_lines "$out") )) left)"
      project_test "$test" && {
        echo $test >> "$out"
      } || {
        warn "Failure <$test>"
      }
    done

    #note "Sleeping for a bit.."
    #sleep 10 || return
    note "Updating $out"
    cat "$out" | sort -u > "$out.tmp"

    diff -q "$in" "$out.tmp" >/dev/null && {
      note "All tests completed" && rm "$in" "$out.tmp" && break
    } || {
      mv "$out.tmp" "$out"
      sleep 5 &&
        comm -2 -3 "$out" "$in" &&
        continue
    }
  done
}

test_status()
{
  false # TODO: summarize test artefacts
}

all_tests_static()
{
  pwd -P &&
  static &&
  all &&
  baselines &&
  required_tests
  #units
}
