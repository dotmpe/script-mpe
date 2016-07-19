#!/usr/bin/env bats

load helper
base=projectdir.sh

init
. $lib/util.sh


setup()
{
  pd=$(pwd)/projectdir.sh \
  testid="$(echo $BATS_TEST_DESCRIPTION | cut -f 1 -d ' ')"
  setup_projdir
  test -s $tmpd/.projects.yaml
}


setup_projdir()
{
  tmpd
  testpd="test/var/pd/$testid.yaml"
  test -e "test/var/pd/$testid.yaml" && {
    cp $testpd $tmpd/.projects.yaml
  } || {
    { cat <<EOF
repositories:
  user-conf:
    default: dev
    disabled: true
    remotes:
      origin: https://github.com/dotmpe/user-conf.git
    sync: true
    clean: untracked
  script-mpe:
    default: dev
    disabled: true
    remotes:
      origin: https://github.com/dotmpe/script-mpe.git
    sync: true
    clean: untracked
EOF
    } > $tmpd/.projects.yaml
  }
}


@test "1.2.1 enable, disable a checkout without errors. " {
  cd $tmpd 
  $pd enable user-conf
  $pd clean user-conf
  $pd disable user-conf
}

@test "1.2.2 update and check for remotes. " {
  cd $tmpd 
  TODO "$BATS_TEST_DESCRIPTION"
}

@test "1.2.3 track enabled per host, or globally. " {
  cd $tmpd 

  # Normal enable/disable switched both global setting, and per-host

  run $pd enable user-conf
  test ${status} -eq 0
#assert_pd "prefixes/user-conf/enabled" true
#  assert_pd "prefixes/user-conf/hosts" ["$hostname"]

  run $pd disable user-conf
  test ${status} -eq 0
#  assert_pd "prefixes/user-conf/enabled" false
#  assert_pd "prefixes/user-conf/hosts" []

  # Per host enables global, but disables only per-host

  run $pd enable-host user-conf
  #test ${status} -eq 0
#  assert_pd "prefixes/user-conf/enabled" true
#  assert_pd "prefixes/user-conf/hosts" ["$hostname"]

  run $pd disable-host user-conf
  #test ${status} -eq 0
#  assert_pd "prefixes/user-conf/enabled" true
#  assert_pd "prefixes/user-conf/hosts" []
}

@test "tell about a prefix; description, remotes, default branch, upstream/downstream settings, other dependencies. " {
  run $pd show script-mpe
  TODO "$BATS_TEST_DESCRIPTION"
}

@test "Pd use-case 4: add a new prefix from existing checkout" {
  TODO "$BATS_TEST_DESCRIPTION"
}


# vim:ft=bash:
