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

./install-dependencies.sh basher

basher help

./install-dependencies.sh all python php dev bats-force-local redo

#pip install https://github.com/bvberkum/docopt-mpe/archive/0.6.x.zip
pip uninstall -qy docopt || true

pip install -q docopt-mpe

#./install-dependencies.sh docopt
#python -c 'import docopt;print(docopt.__version__)'

test "$(whoami)" = "travis" || {
  pip install -q --upgrade pip
}
pip install -q keyring requests_oauthlib
pip install -q gtasks

test -x "$(which tap-json)" || npm install -g tap-json
test -x "$(which any-json)" || npm install -g any-json
npm install nano

test "$(whoami)" = "travis" || {
  not_falseish "$SHIPPABLE" && {
    cpan reload index
    cpan install CAPN
    cpan reload cpan
    cpan install XML::Generator
    test -x "$(which tap-to-junit-xml)" ||
      basher install jmason/tap-to-junit-xml
    tap-to-junit-xml --help || true
  }
}


# FIXME: merge gh-pages into master
#bundle install

# FIXME: npm install parse-torrent lodash

# FIXME: htd install json-spec

#set +e
note "Done"
# Id: script-mpe/0.0.4-dev tools/ci/parts/install.sh
