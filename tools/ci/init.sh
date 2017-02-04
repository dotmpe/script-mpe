#!/bin/bash

. ./tools/sh/env.sh
. ./util.sh
. ./main.lib.sh

note "entry-point for CI pre-install / init phase"


# Basicly if these don't run dont bother with anything,
# But cannot abort/skip a Travis build without failure, can they?

pwd && pwd -P
whoami
env | grep -i 'shippable\|travis\|ci'

# This is also like the classic software ./configure.sh stage.

mkdir -vp ~/.local/{bin,lib,share}

test -e $HOME/.basename-reg.yaml ||
  touch $HOME/.basename-reg.yaml

