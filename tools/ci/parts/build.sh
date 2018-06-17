#!/bin/sh

note "Entry for CI build phase: '$BUILD_STEPS'"

for BUILD_STEP in $BUILD_STEPS
do case "$BUILD_STEP" in

    dev ) lib_load main; main_debug

        note "Esop:"
        (
          export verbosity=7
          esop.sh version || true
          export verbosity=4
          esop.sh version || true
          esop.sh || true
          esop.sh -vv -n help || true
        )

        note "Pd help:"
        (
          ./projectdir.sh help || true
          ./projectdir.sh --version || true
          ./projectdir.sh test bats-specs bats || true
        )

        note "vagrant-sh"
        (
           ./vagrant-sh.sh -h || true
        )

        # TODO install again? note "gtasks:"
        ./gtasks || noop
      ;;

    jekyll )
        bundle exec jekyll build
      ;;

    test-vbox )
      ;;

    test-required ) ;;

    test-others )
        ## Other tests, allow to fail (TODO: complement from REQ_SPECS)
        #note "Testing all specs '$TEST_SPECS'"
        #build_test_init "$REQ_SPECS"
        #(
        #  test_shell $(which bats)
        #) || true
        ;;

    test ) lib_load build

        ## start with essential tests
        note "Testing required specs '$REQ_SPECS'"
        build_test_init "$REQ_SPECS"

        note "Init done"
        (
          # Test shell unit files and report in TAP
          test_shell $(which bats) || echo test-shell >> $failed
          note "Bats shell tests done"
          mv $TEST_RESULTS.tap $TEST_RESULTS-1.tap

          # Test feature files and report in JUnit XML
          echo "Features: '$TEST_FEATURE' '$BUSINESS_SUITE'"
          $TEST_FEATURE $BUSINESS_SUITE || {
            echo test-feature >> $failed
            grep failure $TEST_RESULTS/default.xml
          }
          note "Feature tests done"
          test ! -e $TEST_RESULTS/default.xml ||
            mv $TEST_RESULTS/default.xml $TEST_RESULTS-2.xml

          # Test Python unit files and report in ...
          # FIXME: new params for python tests python $PY_SUITE || touch $failed
          python test/main.py || echo python:main >> $failed

          #py.test --junitxml $TEST_RESULTS.xml $PY_SUITE || touch $failed
          #note "Python unittests done"
          #mv $TEST_RESULTS.xml $TEST_RESULTS-3.xml
        )

        test -e "$TEST_RESULTS-1.tap" || error "Test results 1 expected" 1
        test -e "$TEST_RESULTS-2.xml" || error "Test results 2 expected" 1
        #test -e "$TEST_RESULTS-3.xml" || error "Test results 3 expected" 1

        grep '^not\ ok' $TEST_RESULTS-1.tap &&
            touch $failed ||
            stderr ok "No errors in req-specs"

        test ! -e "$failed" || {
          test -s "$failed" &&
            error "Failed: $(echo $(cat $failed))" ||
            error "Build failed"
        }
      ;;

    noop )
        note "Empty step ($BUILD_STEP)" 0
      ;;

    * )
        error "Unknown step '$BUILD_STEP'" 1
      ;;

  esac

  note "Step '$BUILD_STEP' done"
done

note "Done"

# Id: script-mpe/0.0.4-dev tools/ci/parts/build.sh
