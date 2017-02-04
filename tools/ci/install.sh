#!/bin/bash

set -e

. ./tools/sh/env.sh
. ./util.sh
. ./main.lib.sh

note "entry-point for CI install phase"

test "$(whoami)" = "travis" || {
  apt-get update &&
  apt-get install python-dev realpath uuid-runtime moreutils curl php5-cli

  trueish "$SHIPPABLE" && {
    apt-get install perl
    cpan install XML::Generator
  }
}

./install-dependencies.sh all

npm install parse-torrent lodash

# FIXME: htd install json-spec

