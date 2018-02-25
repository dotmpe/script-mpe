#!/usr/bin/env bats

load init
base=disk.sh

init
. $lib/util.sh


test -n "$device_id" || device_id=disk-id


@test "${bin}" "default no-args" {
  skip "FIXME boreas"
  run $BATS_TEST_DESCRIPTION
  test ${status} -eq 0
}

@test "${bin} status" {
  skip "FIXME boreas"
  run $BATS_TEST_DESCRIPTION
  test ${status} -eq 0
}

@test "${bin} help" {
  run $BATS_TEST_DESCRIPTION
  { test ${status} -eq 0 &&
    fnmatch "*disk.sh*Usage*:*disk <cmd> *" "${lines[*]}"
  } || stdfail
}

@test "${bin} list" {
  run $BATS_TEST_DESCRIPTION
  test ${status} -eq 0
  fnmatch "*Catalog at $(hostname)*" "${lines[*]}"
}

@test "${bin} enable $device_id" {
  run $BATS_TEST_DESCRIPTION
  test ${status} -eq 0
  fnmatch "*enable*Done*" "${lines[*]}"
}

@test "${bin} enable-volumes $device_id" {
  run $BATS_TEST_DESCRIPTION
  test ${status} -eq 0
  fnmatch "*enable-volumes*Done*" "${lines[*]}"
}

@test "${bin} load-catalog $device_id" {
  run $BATS_TEST_DESCRIPTION
  test ${status} -eq 0
  fnmatch "*load-catalog*Loaded*" "${lines[*]}"
}

@test "${bin} import-catalog $device_id" {
  run $BATS_TEST_DESCRIPTION
  test ${status} -eq 0
  fnmatch "*import-catalog*Imported*" "${lines[*]}"
}

@test "${bin} mount $device_id" {
  trueish "$test_disk_mount" || skip "Toggled by test_disk_mount"
  run $BATS_TEST_DESCRIPTION
  test ${status} -eq 0
  fnmatch "*mount*Mounted*at*" "${lines[*]}"
}

@test "${bin} mount-tmp $device_id" {
  trueish "$test_disk_mount" || skip "Toggled by test_disk_mount"
  run $BATS_TEST_DESCRIPTION
  test ${status} -eq 0
  fnmatch "*mount-tmp*Mounted*at temp*" "${lines[*]}"
}

#@test "${bin} copy-fs $device_id" {
#  run $BATS_TEST_DESCRIPTION
#  test ${status} -eq 0
#  fnmatch "*copy-fs*Copied*to*" "${lines[*]}"
#}


