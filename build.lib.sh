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


#        test -z "$failed" -o ! -e "$failed" && {
#          r=0
#          test ! -s "$failed" || {
#            echo "Failed: $(echo $(cat $failed))"
#            rm $failed
#            r=1
#          }
#          unset failed
#        } || true
#
#        exit $r


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
" -w package.yaml -w '*.sh' -w htd "\
" -w tools/sh/env.sh "
  local tests="$(project_tests "$@")"
  test -n "$tests" || error "getting tests '$@'" 1
  note "Watching files: $(echo $tests | tr '\n' ' ')"
  watch_flags="$watch_flags $(echo $tests | sed 's/^/-w /g')"
  #eval nodemon -x \"htd run project-test $(echo $tests | tr '\n' ' ')\" $watch_flags || return $?;
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

retest()
{
  test -n "$1" || set -- totest.list "$2"
  test -n "$2" || set -- "$1" tested.list
  test -s "$1" || {
    project_tests | sort -u > $1
  }
  while true
  do
    # TODO: do-test with lst watch
    cat "$1" | sponge | while read test
    do
        grep -qF "$test" "$2" && continue
        wc -l "$@"
        htd run test "$test" && {
          echo $test >> "$2"
        } || echo "Failure <$test>"
    done
    sleep 1 || return
    cat "$2" | sort -u > "$2.tmp"
    diff -q "$1" "$2.tmp" && {
      note "All tests completed" && rm "$@" "$2.tmp" && break
    } || {
      mv "$2.tmp" "$2"
      sleep 5 &&
        comm -2 -3 "$2" "$1" &&
        continue
    }
  done
}
