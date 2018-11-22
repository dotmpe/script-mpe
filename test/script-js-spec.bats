#!/usr/bin/env bats

load init
base=script.js

init

setup()
{
  projectenv_dep_node=1
  Chrome_TO=1
  stdpreq=node
  #source $scriptpath/util.sh load-ext
  #lib_load str std sys
  lib_load projectenv
  Level_DB="$HOME/Library/Application Support/Google/Chrome/Default/IndexedDB/chrome-extension_eggkanocgddhmamlbiijnphhppkpkmkl_0.indexeddb.leveldb/" 
}

@test "${bin} - No arguments / default action" {
  require_env $stdpreq
  run $bin
  test ${status} -eq 1
  fnmatch "*script.js*missing <command>*" "${lines[*]}" ||
    fail "Out: ${lines[*]}"
}

@test "${bin} - stream key, values" {
  require_env $stdpreq
  run $bin leveldb stream ./mydb
  {
    test ${status} -eq 0 &&
    rm -rf ./mydb
  } || {
    fail "Out: ${lines[*]}"
  }
}

@test "${bin} - stream key, values - LevelDB: Tree Outliner" {

  TODO "Requires TO install, and Chrome must not be running"
  require_env $stdpreq Chrome-TO Level_DB

  # https://groups.google.com/forum/#!topic/tabs-outliner-support-group/eKubL9Iw230
  run $bin leveldb stream "$Level_DB"
  {
    test ${status} -eq 0
  } || {
    fail "Out: ${lines[*]}"
  }
}
