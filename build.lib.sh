#!/bin/sh

set -e


build_lib_load()
{
    true
}

# Set suites for bats, behat and python given specs
build_test_init() # Specs...
{
  test -z "$1" || SPECS="$@"
  test -n "$SPECS" || SPECS='*'

  # NOTE: simply expand filenames from spec first,
  # then sort out testfiles into suites based on runner
  local suite=/tmp/htd-build-test-suite-$(uuidgen).list
  project_tests $SPECS > $suite
  wc -l $suite
  test -s "$suite" || error "No specs for '$*'" 1
  BUSINESS_SUITE="$( grep '\.feature$' $suite | lines_to_words )"
  BATS_SUITE="$( grep '\.bats$' $suite | lines_to_words )"
  PY_SUITE="$( grep '\.py$' $suite | lines_to_words )"
  # SUITE="$(project_tests | lines_to_words)"
}

# TODO
build_matrix()
{
  echo
}


test_shell()
{
  test -n "$*" || set -- bats
  local verbosity=4
  echo "test-shell: '$@' '$BATS_SUITE' | tee $TEST_RESULTS" >&2
  eval $@ $BATS_SUITE | tee $TEST_RESULTS
}


# Run tests for DUT's
project_test() # [Units...|Comps..]
{
  set -- $(project_tests "$@")
  local failed=/tmp/htd-project-test-$(uuidgen).failed
  while test $# -gt 0
  do
    case "$1" in
        *.feature ) $TEST_FEATURE -- "$1" || touch $failed ;;
        *.bats ) {
                bats "$1" || touch $failed
            } | $TAP_COLORIZE ;;
        *.py ) python "$1" || touch $failed ;;
    esac
    shift
  done

  test -e "$failed" && { rm "$failed" ; return 1 ; }
  note "Project test completed succesfully"
}

# Echo test file names
project_tests() # [Units..|Comps..]
{
  test -n "$1" || set -- "*"
  while test $# -gt 0
  do
      any_unit "$1"
      any_feature "$1"
      case "$1" in *.py|*.bats|*.feature )
          test -e "$1" && echo "$1" ;;
      esac
    shift
  done | sort -u
}

project_files()
{
  test -z "$1" && git ls-files ||
  while test $# -gt 0
  do
    git ls-files "$1*sh"
    shift
  done | sort -u
}

any_unit()
{
  test -n "$1" || set -- "*"
  while test $# -gt 0
  do
    c="-_*" mkid "$1"
    mkvid "$1"
    for x in test/py/$id.py test/py/mod_$vid.py test/$id-lib-spec.bats test/$id-spec.bats test/$id.bats
    do
      test -e "$x" && echo $x
      continue
    done
    shift
  done
}

any_feature()
{
  test -n "$1" || set -- "*"
  while test $# -gt 0
  do
    c="-_*" mkid "$1"
    for x in test/$id.feature test/$id-lib-spec.feature test/$id-spec.feature
    do
      test -e "$x" && echo $x
      continue
    done
    shift
  done
}

test_any_feature()
{
  pwd -P
  info "Test any feature '$*'"
  test -n "$1" && {
    local features="$(any_feature "$@" | tr '\n' ' ')"
    test -n "$features" || error "getting features '$@'" 1
    note "Features: $features"
    $TEST_FEATURE $features || return $?;

  } || {
    $TEST_FEATURE || return $?;
  }
}

test_watch()
{
  local watch_flags=" -w test/bootstrap/FeatureContext.php "\
" -w package.yaml -w build.lib.sh -w tools/sh/env.sh "
  local tests="$(project_tests "$@")" files="$(project_files "$@")"
  test -n "$tests" || error "getting tests '$@'" 1
  note "Watching files: $(echo $tests)"
  watch_flags="$watch_flags $(echo "$tests" | sed 's/^/-w /g' | tr '\n' ' ' )"\
" $(echo "$files" | sed 's/^/-w /g' | tr '\n' ' ' )"
  note "Watch flags '$watch_flags'"
  nodemon -x "htd run project-test $(echo $tests | tr '\n' ' ')" $watch_flags || return $?;
}

feature_watch()
{
  watch_flags=" -w test/bootstrap/FeatureContext.php "
  test -n "$1" && {
    local features="$(any_feature "$@")"
    note "Watching files: $features"
    watch_flags="$watch_flags $(echo $features | sed 's/^/-w \&/')"
    nodemon -x "$TEST_FEATURE $(echo $features | tr '\n' ' ')" $watch_flags || return $?;

  } || {
    $TEST_FEATURE || return $?;
    nodemon -x "$TEST_FEATURE" $watch_flags -w test || return $?;
  }
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
retest()
{
  local in= out= #$1 out=$2 ; shift 2
  test -n "$in" || in=totest.list
  test -n "$out" || out=tested.list
  test -e "$in" || touch totest.list
  test -e "$out" || touch tested.list
  test -s "$in" || {
    project_tests "$@" | sort -u > $in
  }
  while true
  do
    # TODO: do-test with lst watch
    read_nix_style_file "$in" | while read test
    do
        grep -qF "$test" "$out" && continue
        note "Running '$test'... ($(( $(count_lines "$in") - $(count_lines "$out") )) left)"
        ( htd run test "$test" ) && {
          echo $test >> "$out"
        } || {
          warn "Failure <$test>"
        }
    done
    note "Sleeping for a bit.."
    sleep 60 || return
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

# Checkout from given remote if it is ahead, for devops work on branch & CI.
# Allows to update from amended commit in separate (local/dev) repository,
# w/o adding new commit and (for some systems) getting a new build number.
checkout_if_newer()
{
  test -n "$1" -a -n "$2" -a -n "$3" || error checkout-if-newer.args 1
  test -z "$4" || error checkout-if-newer.args 2

  local behind= url="$(git config --get remote.$2.url)"
  test -n "$url" && {
    test "$url" = "$3" || git remote set-url $2 $3
  } || git remote add $2 $3
  git fetch $2
  behind=$( git rev-list $1..$2/$1 --count )
  test $behind -gt 0 && {
    from="$(git rev-parse HEAD)"
    git checkout --force $2/$1
    to="$(git rev-parse HEAD)"
    export BUILD_REMOTE=$2 BUILD_BRANCH_BEHIND=$behind \
        BUILD_COMMIT_RANGE=$from...$to
  }
}

checkout_for_rebuild()
{
  test -n "$1" -a -n "$2" -a -n "$3" || error checkout_for_rebuild-args 1
  test -z "$4" || error checkout_for_rebuild-args 2

  test -n "$BUILD_CAUSE" || export BUILD_CAUSE=$TRAVIS_EVENT_TYPE
  test -n "$BUILD_BRANCH" || export BUILD_BRANCH=$1

  export BUILD_COMMIT_RANGE=$TRAVIS_COMMIT_RANGE
  checkout_if_newer "$@" && export \
    BUILD_CAUSE=rebuild \
    BUILD_REBUILD_WITH="$(git describe --always)"
}

before_test()
{
  verbose=1 git-versioning check &&
  projectdir.sh run :bats:specs
}
