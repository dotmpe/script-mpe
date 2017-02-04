#!/bin/bash

set -e

. ./tools/sh/env.sh
. ./util.sh
. ./main.lib.sh

note "entry-point for CI install phase"

test "$(whoami)" = "travis" || {
  apt-get update &&
  apt-get install php5 python-dev
}

apt-get remove python-six

./install-dependencies.sh pip

pip install packaging appdirs
pip install --upgrade --user -r requirements.txt
pip install --upgrade --user -r test-requirements.txt

npm install parse-torrent lodash

./install-dependencies.sh all

pip install --user nose-parameterized

htd install json-spec

