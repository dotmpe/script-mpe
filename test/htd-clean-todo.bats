#!/bin/bash

load helper


setup()
{
  tmpd=/tmp/htd-clean-spec
  test ! -e $tmpd || rm -rf $tmpd

  test -e ~/Downloads && {
    mkdir $tmpd
    diag "Testdir: $tmpd"
    cd $tmpd

    # Test on collection of downloaded files
    #cp ~/Downloads/{dev/script/shadow,mytest,games/adventure,dev/electronics/ESPEasy_R120}.zip $tmpd
    cp ~/Downloads/mytest.zip $tmpd

    for z in *.zip
    do diag "Found archive: $z" ; unzip $z -d $tmpd; done
  }
}

@test "htd clean" {

  TODO "get help from annex"
  test -e "$tmpd" || skip "No test dir found"
  run htd clean
  test_ok_nonempty || stdfail "Unexpected: $status <$tmpd>"
}
