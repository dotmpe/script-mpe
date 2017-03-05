#!/usr/bin/env bats

load helper
base=script.js

init

source $lib/util.sh load-ext
lib_load str std sys


@test "${bin} - No arguments / default action" {
  run $bin
  test ${status} -eq 1
  fnmatch "*script.js*missing <command>*" "${lines[*]}" ||
    fail "Out: ${lines[*]}"
}

@test "${bin} - stream key, values" {
  run $bin leveldb stream ./mydb
  {
    test ${status} -eq 0
    rm -rf ./mydb
  } || {
    fail "Out: ${lines[*]}"
  }
}

@test "${bin} - stream key, values - LevelDB: Tree Outliner" {

	TODO "Requires TO install, and Chrome must not be running"

  # https://groups.google.com/forum/#!topic/tabs-outliner-support-group/eKubL9Iw230
  run $bin leveldb stream "$HOME/Library/Application Support/Google/Chrome/Default/IndexedDB/chrome-extension_eggkanocgddhmamlbiijnphhppkpkmkl_0.indexeddb.leveldb/" 
  {
    test ${status} -eq 0
  } || {
    fail "Out: ${lines[*]}"
  }
}


