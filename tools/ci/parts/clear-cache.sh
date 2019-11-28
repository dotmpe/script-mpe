#!/usr/bin/env bash

# Remove cache if requested before build (but leave working space)

test "$BUILD_PRE_INIT_CACHE_CLEAR" = "0" || {
  test -e .htd/travis.json -a .htd/travis.json -nt .travis.yml && {

    rm -rf  $(jq -r '.cache.directories[]' .htd/travis.json)
    $INIT_LOG "warn" "" "Dropped cache" ".htd/travis.json#.cache.directories[]"

  } || {

    deps="$( grep -v '^\s*\(#.*\|\s*\)$' dependencies.txt|grep '^git'| cut -f2 -d' ')"
    rm -rf \
         ./node_modules \
         ./vendor \
         $HOME/.other \
         $HOME/.basher \
         $HOME/.cache/pip \
         $HOME/virtualenv \
         $HOME/.npm \
         $HOME/.composer \
         $HOME/.rvm/ \
         $HOME/.statusdir/ \
         $HOME/build/apenwarr \
         $HOME/build/ztombol \
         $deps \
         $HOME/build/dotmpe/user-conf \
         $HOME/build/dotmpe/docopt-mpe \
         $HOME/build/dotmpe/git-versioning \
         $HOME/build/dotmpe/bats-core || true
    unset deps
    $INIT_LOG "warn" "" "Tried to drop cached dirs"
  }
}
# Sync: U-S:
