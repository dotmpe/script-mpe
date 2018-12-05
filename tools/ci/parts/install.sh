#!/bin/bash

note "Entry for CI install phase ($scriptname)"


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

pip uninstall -qy docopt || true
./install-dependencies.sh test bats-force-local
for x in composer.lock .Gemfile.lock
do
  test -e $x || continue
  rsync -avzui $x .htd/$x
done


test "$(whoami)" = "travis" || {
  pip install -q --upgrade pip
}

pip install -q keyring requests_oauthlib
pip install -q gtasks

test -x "$(which tap-json)" || npm install -g tap-json
test -x "$(which any-json)" || npm install -g any-json
npm install nano

which github-release || npm install -g github-release-cli

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

gem install travis

# FIXME: merge gh-pages into master
#bundle install

# FIXME: npm install parse-torrent lodash

# FIXME: htd install json-spec

ci_install_end_ts=$($gdate +"%s.%N")

note "Done"
# Id: script-mpe/0.0.4-dev tools/ci/parts/install.sh
