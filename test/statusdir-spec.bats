#!/usr/bin/env bats

load helper
base=statusdir.sh
init


@test "${bin}" "default no-args" {
  #case $(current_test_env) in travis )
  #    TODO "$BATS_TEST_DESCRIPTION at travis";;
  #esac

  rt()
  {
    echo $BATS_TEST_DESCRIPTION > /tmp/1
    $BATS_TEST_DESCRIPTION >> /tmp/1 2>&1 || echo "$?" >> /tmp/1
  }
  rt

  run $BATS_TEST_DESCRIPTION
  test ${status} -eq 1
  echo "${status}" >> /tmp/1
  echo "${lines[*]}" >> /tmp/1
}

@test "${bin} help" {
  run $BATS_TEST_DESCRIPTION
  test ${status} -eq 0
  fnmatch "*statusdir <cmd> *" "${lines[*]}"
}

@test "${bin} root" {
  run $BATS_TEST_DESCRIPTION
  test ${status} -eq 0
  test "$HOME/.statusdir/" = "${lines[*]}"
}

#@test "${bin} assert-state $HOME/project/git-versioning/package.yaml project/git-versioning {}" {
#  run $BATS_TEST_DESCRIPTION
#  test ${status} -eq 0
#}

@test "${bin} assert-json" {
  run $BATS_TEST_DESCRIPTION
  test ${status} -eq 0
  test "$HOME/.statusdir/index/state.json" = "${lines[*]}"
}



@test "${bin} list" {
  require_env couchdb
  run statusdir.sh 
}

# vim:ft=sh:
