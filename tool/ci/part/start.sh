#!/usr/bin/env bash

ci_announce "Starting CI session <$SUITE, $B>"

test -n "${passed:-}" || {
  mkdir -p $B/reports/{Sh,CI,Main,Test}
  export SESSION_ID="$(uuidgen)"
  export verbosity SUITE BUILD B

  tmpf="$TMPDIR/sh-$SUITE-run-$SESSION_ID"

  export passed="$tmpf.passed"
  echo "# Status Command-Spec">"$passed"
  export failed="$tmpf.failed"
  echo "# Status Command-Spec">"$failed"
  $LOG note "" "Started reporter session at" "$tmpf"

  unset tmpf
}
# Sync: U-S:
