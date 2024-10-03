#!/bin/sh

test -n "${TEST_FEATURE_BIN:-}" -o ! -x "./vendor/bin/behat" ||
    TEST_FEATURE_BIN="./vendor/bin/behat"
test -n "${TEST_FEATURE_BIN:-}" || TEST_FEATURE_BIN="$(which behat || true)"
test -n "${TEST_FEATURE_BIN:-}" && {
    # Command to run one or all feature tests
    test -n "$TEST_RESULTS" && {
        TEST_FEATURE="$TEST_FEATURE_BIN -f junit -o$TEST_RESULTS --tags '~@todo&&~@skip' --suite default"
    } || {
        TEST_FEATURE="$TEST_FEATURE_BIN --tags '~@todo&&~@skip' --suite default"
    }
    # XXX: --tags '~@todo&&~@skip&&~@skip.travis'
    # Command to print def lines
    TEST_FEATURE_DEFS="$TEST_FEATURE_BIN -dl"
}

test -n "${TEST_FEATURE:-}" || {
    test -n "${TEST_FEATURE_BIN:-}" || TEST_FEATURE_BIN="$(command -v behave || true)"
    test -n "$TEST_FEATURE_BIN" && {
        TEST_FEATURE="$TEST_FEATURE_BIN --tags '~@todo' --tags '~@skip' -k"
    }
}

test -n "${TEST_FEATURE:-}" || {
    error "Nothing to test features with"
    TEST_FEATURE="echo No Test-Feature for"
}

# Sync: U-S:
