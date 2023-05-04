#!/usr/bin/env bash

# x TODO: want to see history for github network, find interesting repos

set -e

GH_REPO=meltwater/docker-cleanup

test "$(basename "$0")" = "git-network-tree.sh" || {
  echo Must be executed as script >&2
  exit 1
}

bn=$(basename $GH_REPO)
scriptcpath=$(realpath "$0")

cd $(dirname "$scriptcpath")
test -d "$bn" || {
  git clone https://github.com/$GH_REPO || exit $?
}

cd "$bn"
# FIXME: credentials needed
test -e .gh-network.json || cp ../meta.json .gh-network.json
test -e .gh-network.json || {
  curl https://github.com/$GH_REPO/network/meta -o .gh-network.json || exit $?
}

. ~/.conf/script/os-uc.lib.sh
os_uc_lib__load
. ~/.conf/script/date-uc.lib.sh
GIT_AGE=$_1DAY
GIT_AGE=$_3HOUR

jq -r '.users[] as $k | $k.name+" "+$k.repo' .gh-network.json |
  while read user repo
do
  git config --get remote.$user.url >/dev/null 2>&1 || {
    git remote add $user https://github.com/$user/$repo
  }
  # XXX: this is not faster than fetch all, and may not work as expected
  #newer_than .git/logs/refs/remotes/$user $GIT_AGE || {
  #  git fetch $user
  #  touch .git/refs/remotes/$user
  #}
  #echo Remote $user OK
  continue
done
git fetch --all

#git tree
#git log --graph --full-history --all --color --date=short --pretty=format:"%x1b[31m%h%x09%x1b[0m%x20%ad%x1b[32m%d%x1b[0m %aN: %s"
