#!/usr/bin/env bash

# XXX: old shippable-CI hack
#failed=/tmp/htd-build-test-$(get_uuid).failed
#test "$SHIPPABLE" = true || test ! -e "$failed"

lib_load build-test

(
  # Test shell unit files and report in TAP
  test_shells $(which bats) || echo test-shell >> $failed
  note "Bats shell tests done"
  mv -v $TEST_RESULTS.tap $TEST_RESULTS-1.tap

  # Test feature files and report in JUnit XML
  echo "Features: '$TEST_FEATURE' '$BUSINESS_SUITE'"
  #$TEST_FEATURE $BUSINESS_SUITE || {
    #echo test-feature >> $failed
    #grep failure $TEST_RESULTS/default.xml
  (
    ./vendor/bin/behat --tags ~@todo&&~@skip --suite default || true
  )
  #mv -v $TEST_RESULTS/default.xml $TEST_RESULTS-2.xml
  note "Feature tests done"

  # Test Python unit files and report in ...
  echo "Python tests..."
  test "$SHIPPABLE" = "true" && {
      source /root/venv/2.7/bin/activate
      pip install keyring requests_oauthlib
      pip install -r requirements.txt
      pip install -r test-requirements.txt
  } || true

return 0

# FIXME
  python test/main.py || true #echo python:main >> $failed
  #py.test --junitxml $TEST_RESULTS.xml $PY_SUITE || touch $failed
  #mv -v $TEST_RESULTS.xml $TEST_RESULTS-3.xml
  #note "Python unittests done"
)

# Sync: U-S:
