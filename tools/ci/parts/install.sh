#!/bin/bash

note "Entry for CI install phase"


test "$(whoami)" = "travis" || {
  export sudo=sudo

  test -x "$(which apt-get)" && {
    test -z "$APT_PACKAGES" ||
    {
      echo sudo=$sudo APT_PACKAGES=$APT_PACKAGES
      {
        $sudo apt-get update &&
        $sudo apt-get install $APT_PACKAGES

      } || error "Error installing APT packages" 1
    }
  }
}

sudo=$sudo ./install-dependencies.sh all pip php dev bats-force-local

pip install keyring requests_oauthlib
pip install gtasks

test -x "$(which tap-json)" || npm install -g tap-json
test -x "$(which any-json)" || npm install -g any-json
npm install nano

#test "$(whoami)" = "travis" || {
#  not_falseish "$SHIPPABLE" && {
#    $sudo apt-get install perl
#    cpan reload index
#    cpan install XML::Generator
#    test -x "$(which tap-to-junit-xml)" ||
#      basher install jmason/tap-to-junit-xml
#    tap-to-junit-xml --help || noop
#  }
#}


# FIXME: merge gh-pages into master
#bundle install

# FIXME: npm install parse-torrent lodash

# FIXME: htd install json-spec

#set +e
note "Done"
# Id: script-mpe/0.0.4-dev tools/ci/parts/install.sh
