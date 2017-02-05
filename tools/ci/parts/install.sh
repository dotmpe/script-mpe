#!/bin/bash

set -e

note "Entry for CI install phase"


test "$(whoami)" = "travis" || {

  test -x "$(which apt-get)" && {
    test -z "$APT_PACKAGES" ||
    {
      {
        $sudo apt-get update &&
        $sudo apt-get install $APT_PACKAGES

      } || error "Error installing APT packages" 1
    }
  }
}

./install-dependencies.sh all

test "$(whoami)" = "travis" || {
  trueish "$SHIPPABLE" && {
    test -x "$(which tap-to-junit-xml)" ||
      basher install jmason/tap-to-junit-xml
    $sudo apt-get install perl
    cpan reload index
    cpan install XML::Generator
  }
}


# FIXME: merge gh-pages into master
#bundle install


# FIXME: npm install parse-torrent lodash

# FIXME: htd install json-spec

note "Done"

