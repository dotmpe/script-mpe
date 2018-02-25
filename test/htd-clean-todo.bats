#!/bin/bash


setup()
{
  tmpd=/tmp/htd-clean-spec
  test ! -e $tmpd || rm -rf $tmpd

  test -e ~/Downloads && {
    mkdir $tmpd
    diag "Testdir: $tmpd"
    cd $tmpd

    # Test on collection of downloaded files
    cp ~/Downloads/{shadow,mytest,adventure,ESPEasy_R120}.zip $tmpd

    # unpack all zips into root except mytest
    mkdir $tmpd/mytest
#    unzip $tmpd/mytest.zip -d $tmpd/mytest
    mv $tmpd/mytest.zip $tmpd/mytest/

    for z in *.zip
    do diag "Found archive: $z" ; unzip $z -d $tmpd; done

    mv $tmpd/mytest/mytest.zip $tmpd/
  }
}

@test "htd clean" {

  test -e "$tmpd" || skip "No test dir found"
  run htd clean
  test_ok_non_empty || stdfail "Unexpected: $status <$tmpd>"
}
