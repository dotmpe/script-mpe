#!/bin/ash


note "Entry for CI install phase ($scriptname)"


# Simple from-github provisioning script for user-script repos

update_supportlib()
{
  test -n "$1" || set -- "master" "$2"
  test -n "$2" || set -- "$1" "origin"
  git fetch --all && git fetch --tags && git reset --hard $2/$1
}


list_supportlibs()
{

  #echo user-tools/user-scripts
  #echo user-tools/user-scripts-incubator
  #echo user-tools/user-conf

  echo bvberkum/script-mpe
  echo bvberkum/user-scripts
  echo bvberkum/user-scripts-incubator
  echo bvberkum/user-conf
  echo bvberkum/script-mpe

  echo ztombol/bats-file
  echo ztombol/bats-support
  echo ztombol/bats-assert

}


test -d "$VND_GH_SRC" -a -w "$VND_GH_SRC" ||
  $LOG error ci:install "Writable Github vendor dir expected" "$VND_GH_SRC" 1


list_supportlibs | while read supportlib
do
  $LOG "info" "" "Checking $supportlib..."

  ns_name="$(dirname "$supportlib")"
  test -d "$VND_GH_SRC/$ns_name" || mkdir -p "$VND_GH_SRC/$ns_name"

  # Create clone at path, check for Git dir to not be fooled by any cache/mount
  test -e "$VND_GH_SRC/$supportlib/.git" || {

    test ! -e "$VND_GH_SRC/$supportlib" || rm -rf "$VND_GH_SRC/$supportlib"
    git clone https://github.com/$supportlib "$VND_GH_SRC/$supportlib"
  }

  cd "$VND_GH_SRC/$supportlib" && update_supportlib
done

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

which github-release || go get github.com/aktau/github-release

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
