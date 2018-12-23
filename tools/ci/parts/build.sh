#!/bin/sh

note "Entry for CI build phase: '$BUILD_STEPS'"
export ci_build_ts="$($gdate +"%s.%N")"


sh ./sh-github

for BUILD_STEP in $BUILD_STEPS
do case "$BUILD_STEP" in

        true )
            note "Empty step ($BUILD_STEP)" 0
          ;;

        test ) ;; # FIXME build test

        * )
            test -e "./tools/sh/build/$BUILD_STEP.sh" || {
                error "No such build-script '$BUILD_STEP'" 1
            }

            . ./tools/sh/build/$BUILD_STEP.sh
          ;;

  esac

  note "Step '$BUILD_STEP' done"
done


export ci_build_end_ts="$($gdate +"%s.%N")"
note "Done"

# Id: script-mpe/0.0.4-dev tools/ci/parts/build.sh
