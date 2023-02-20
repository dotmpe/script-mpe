#!/usr/bin/env bats

load init
base=statusdir.sh
init

setup()
{
  load stdtest extra &&
  export \
    COUCH_DB=test \
    MC_PORT=11211
}

@test "statusdir.sh" "default no-args" {
  # Default equals std__usage
  run $bin
  test_nok_nonempty || stdfail
}

@test "statusdir.sh help" {
  run $bin help
  test_ok_nonempty "*statusdir <cmd> *" || stdfail
}

@test "statusdir.sh root" {
  run $bin root
  test_ok_lines "${STATUSDIR_ROOT:-$HOME/.local/statusdir/}" || stdfail
}

@test "statusdir.sh assert-state $HOME/project/git-versioning/package.yaml project/git-versioning {}" {
  TODO
  run $BATS_TEST_DESCRIPTION
  test ${status} -eq 0
}

@test "statusdir.sh assert-json" {
  run $bin assert-json
  test ${status} -eq 0
  test "${STATUSDIR_ROOT:-$HOME/.local/statusdir/}index/state.json" = "${lines[*]}"
}

@test "sd_be=redis statusdir.sh list" {
  #lib_load projectenv
  #require_env couchdb || req
  run sd_be=redis $bin list
}

@test "statusdir.sh backends" {
  run $bin backends
  test_ok_lines \
      "*fsdir found*" \
      "*redis *" \
      "*membash *" \
      "*couchdb_sh *" \
      || stdfail
}

@test "sd_be=couchdb_sh statusdir.sh backend" {
  export sd_be=couchdb_sh
  run $bin backend
  test_ok_lines "couchdb $COUCH_URL $COUCH_DB" || stdfail
} 

@test "sd_be=membash statusdir.sh backend" {
  export sd_be=membash
  run $bin backend
  test_ok_lines "memcache $MC_PORT" || stdfail
} 

# vim:ft=sh:
