#!/bin/bash

set -e

. ./tools/sh/env.sh
. ./util.sh
. ./main.lib.sh

note "entry-point for CI install phase"


mkdir -vp ~/.local/{bin,lib,share}

pip install --upgrade --user -r requirements.txt
pip install --upgrade --user -r test-requirements.txt

npm install parse-torrent lodash

./install-dependencies.sh all

pip install --user nose-parameterized

test -e $HOME/.basename-reg.yaml ||
  touch $HOME/.basename-reg.yaml


