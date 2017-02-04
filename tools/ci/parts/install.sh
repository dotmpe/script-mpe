#!/bin/bash

set -e

. ./tools/sh/env.sh
. ./util.sh
. ./main.lib.sh

note "entry-point for CI install phase"

test "$(whoami)" = "travis" || {
  apt-get update &&
  apt-get install python-dev realpath uuid-runtime moreutils curl php5-cli
}

./install-dependencies.sh all

test "$(whoami)" = "travis" || {
  trueish "$SHIPPABLE" && {
    test -x "$(which tap-to-junit-xml)" ||
      basher install jmason/tap-to-junit-xml
    apt-get install perl
    cpan reload index
    cpan install XML::Generator
  }
}

npm install parse-torrent lodash

# FIXME: htd install json-spec

