#!/bin/sh

$LOG note "" "Entry for CI build phase: '$BUILD_STEPS'"
export ci_build_ts="$($gdate +"%s.%N")"
ci_stages="$ci_stages ci_build"


for BUILD_STEP in $BUILD_STEPS
do case "$BUILD_STEP" in

    true )
        note "Empty step ($BUILD_STEP)" 0
      ;;

    test ) ;; # FIXME build test

    * )
        test -e "$script_util/build/$BUILD_STEP.sh" || {
            $LOG error "" "No such build-script '$BUILD_STEP'" "" 1
        }

        . $script_util/build/$BUILD_STEP.sh
      ;;

  esac

  $LOG note "" "Step '$BUILD_STEP' done"
done


export ci_build_end_ts="$($gdate +"%s.%N")"
$LOG note "" "Done"

# Id: script-mpe/0.0.4-dev tools/ci/parts/build.sh
