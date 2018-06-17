#!/bin/bash

note "Entry for CI install phase"


test "$(whoami)" = "travis" || {

  test -x "$(which apt-get)" && {
    test -z "$APT_PACKAGES" ||
    {
      echo APT_PACKAGES=$APT_PACKAGES
      {
          echo '------'
    apt-cache search git
          echo '------'
    apt-cache search lfs
          echo '------'

        $sudo apt-get update &&
        $sudo apt-get install $APT_PACKAGES

      } || error "Error installing APT packages" 1
    }
  }
}

./install-dependencies.sh all pip php dev bats-force-local

pip install gtasks

test -x "$(which tap-json)" || npm install -g tap-json
test -x "$(which any-json)" || npm install -g any-json
npm install nano

test "$(whoami)" = "travis" && {
  true
} || {
  not_falseish "$SHIPPABLE" && {
    $sudo apt-get install perl
    cpan reload index
    cpan install XML::Generator
    test -x "$(which tap-to-junit-xml)" ||
      basher install jmason/tap-to-junit-xml
    tap-to-junit-xml --help || noop
  }
}


# FIXME: merge gh-pages into master
#bundle install

# FIXME: npm install parse-torrent lodash

# FIXME: htd install json-spec

#set +e
note "Done"
# Id: script-mpe/0.0.4-dev tools/ci/parts/install.sh
