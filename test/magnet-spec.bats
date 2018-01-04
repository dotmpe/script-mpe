#!/usr/bin/env bats
  
base=magnet.py
load helper
init


@test "$bin no arguments no-op" {
  run $bin
  { test_ok_nonempty
  } || stdfail 1
}

@test "$bin -h" {
  run $BATS_TEST_DESCRIPTION
  { test_ok_nonempty
  } || stdfail 1
}

@test "$bin fixture" {
  _test() {
    while read url_or_file tags
    do
      magnet_url=$( magnet.py $url_or_file )
      for tag in $tags
      fnmatch *"$tags"* "$magnet_url" || {
        echo "Error: missing tag '$tag' for '$url_or_file': '$magnet_url'"
        return 1
      }
    done
  }
  run _test
  { test_ok_nonempty
  } || stdfail 1
}
