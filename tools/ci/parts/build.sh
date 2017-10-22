#!/bin/sh

note "Entry for CI build phase: '$BUILD_STEPS'"

for BUILD_STEP in $BUILD_STEPS
do case "$BUILD_STEP" in

    dev ) lib_load main; main_debug

        #note "Pd help:"
        # FIXME: "Something wrong with pd/std__help"
        #(
        #  ./projectdir.sh help || noop
        #)
        #./projectdir.sh test bats-specs bats

        # TODO install again? note "gtasks:"
        #./gtasks || noop

        #note "Htd script:"
        #htd script

        #note "basename-reg:"
        #./basename-reg ffnnec.py

        note "mimereg:"
        (
           ./mimereg ffnenc.py
        ) || true

        #note "lst names local:"
        #892.2 https://travis-ci.org/dotmpe/script-mpe/jobs/191996789
        #lst names local
        # [lst.bash:names] Warning: No 'watch' backend
        # [lst.bash:names] Resolved ignores to '.bzrignore etc:droppable.globs
        # etc:purgeable.globs .gitignore .git/info/exclude'
        #/home/travis/bin/lst: 1: exec: 10: not found
      ;;

    jekyll )
        bundle exec jekyll build
      ;;

    test-vbox )
      ;;

    test-feature )
      ;;

    test )
        lib_load build

        test -n "$TEST_RESULTS" || TEST_RESULTS=build/test-results-specs.tap
        test -d "$(dirname "$TEST_RESULTS")" ||
          mkdir -vp "$(dirname "$TEST_RESULTS")"

        failed=build/test-results-failed.list


        ## start with essential tests
        #note "Testing '$REQ_SPECS'"

        #for spec in $REQ_SPECS ; do
        #  SUITE="$spec" test_shell > $TEST_RESULTS
        #done

        (
          SUITE="$REQ_SPECS" test_shell $TEST_SHELL $(which bats)
        ) || touch $failed

        not_falseish "$SHIPPABLE" && {
          perl $(which tap-to-junit-xml) --input $TEST_RESULTS \
            --output $(basepath $TEST_RESULTS .tap .xml)
          wc -l $TEST_RESULTS $(basepath $TEST_RESULTS .tap .xml)
        } || {
          wc -l $TEST_RESULTS
        }

        ## Other tests
        note "Testing '$TEST_SPECS'"
        (
          SUITE="$TEST_SPECS" test_shell
        ) || noop

        # TODO: integrate feature testing
        (
          test_features
        ) || noop

        test -z "$failed" -o ! -e "$failed" && {
          r=0
          test ! -s "$failed" || {
            echo "Failed: $(echo $(cat $failed))"
            rm $failed
            r=1
          }
          unset failed
        } || true

        exit $r
      ;;

    noop )
        # TODO: make sure nothing, or as little as possible has been installed
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
