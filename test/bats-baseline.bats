#!/h usr/bin/env bats

base=bats-baseline
load init


# TODO: test envs are isolated, use other service to record status so
# next test can query for prev. test state.
#teardown()
#{
#  diag "BATS_TEST_COMPLETED=$BATS_TEST_COMPLETED"
#  diag "BATS_ERROR_STATUS=$BATS_ERROR_STATUS"
#  diag "BATS_COUNT_ONLY=$BATS_COUNT_ONLY"
#}
