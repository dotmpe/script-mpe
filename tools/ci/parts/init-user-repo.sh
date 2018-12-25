#!/bin/ash

ci_announce "Entry for CI install phase ($scriptname)"

# TODO: list versions/tags per supportlib or checkout latest tag


# Simple from-github provisioning script for user-script repos

update_supportlib()
{
  test -n "$1" || set -- "master" "$2"
  test -n "$2" || set -- "$1" "origin"

  git fetch --all --quiet && git fetch --tags --quiet &&
  git reset --quiet --hard $2/$1
}


list_supportlibs()
{

  #echo user-tools/user-scripts
  #echo user-tools/user-scripts-incubator
  #echo user-tools/user-conf

  echo bvberkum/script-mpe features/docker-ci
  echo bvberkum/user-scripts r0.0
  #echo bvberkum/user-scripts-incubator test
  echo bvberkum/user-conf

  echo ztombol/bats-file
  echo ztombol/bats-support
  echo ztombol/bats-assert

}


test -d "$VND_GH_SRC" -a -w "$VND_GH_SRC" &&
  $LOG note ci:install "Using Github vendor dir" "$VND_GH_SRC" ||
  $LOG error ci:install "Writable Github vendor dir expected" "$VND_GH_SRC" 1

test "$(whoami)" = "travis" && {
  list_supportlibs | while read supportlib version
  do
    $LOG "info" "" "Checking $supportlib..."

    ns_name="$(dirname "$supportlib")"
    test -d "$VND_GH_SRC/$ns_name" || mkdir -p "$VND_GH_SRC/$ns_name"

    # Create clone at path, check for Git dir to not be fooled by any cache/mount
    test -e "$VND_GH_SRC/$supportlib/.git" || {

      test ! -e "$VND_GH_SRC/$supportlib" || rm -rf "$VND_GH_SRC/$supportlib"
      git clone --quiet https://github.com/$supportlib "$VND_GH_SRC/$supportlib"
    }

    cd "$VND_GH_SRC/$supportlib" && update_supportlib "$version"
  done
} || true
