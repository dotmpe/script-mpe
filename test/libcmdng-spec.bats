#!/usr/bin/env bats


@test "TODO: update old scripts" {
    # mpe -> main.py, see also rsr2, txs.py
    mpe cmd:prog
    mpe cmd:config
    mpe cmd:options
#	mpe cmd:help
    mpe cmd:targets
    mpe txs:session
    mpe txs:pwd
    mpe txs:ls
    mpe txs:run
    mpe rsr:volume
}
