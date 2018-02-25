#!/usr/bin/env bats
  
base=magnet.py
load init
init


@test "$bin no arguments is err" {

  run $bin ; test_nok_nonempty || stdfail 1
}

@test "$bin -h" {

  run $BATS_TEST_DESCRIPTION ; test_ok_nonempty || stdfail 1
}

@test "$bin fixture" {

  _test() {
    while read url_or_file tags ; do
      magnet_url=$( magnet.py $url_or_file )
      for tag in $tags ; do
        case "$magnet_url" in *"$tags"* )
            echo "Error: missing tag '$tag' for '$url_or_file': '$magnet_url'"
            return 1
          ;;
        esac
      done
    done < test/var/magnet-urls.tab
  }

  run _test ; test_ok_empty || stdfail 1
}
