#!/bin/bash


setup()
{
  tmpd=/tmp/htd-clean-spec
  test -! -e $tmpd || rm -rf $tmpd
  mkdir $tmpd

  # Test on collection of downloaded files
  cp ~/Downloads/*.zip $tmpd

  # unpack all zips into root except mytest
  mkdir $tmpd/mytest
  unzip $tmpd/mytest.zip -d $tmpd/mytest
  mv $tmpd/mytest.zip $tmpd/mytest/

  for z in *.zip
  do unzip $z -d $tmpd; done

  mv $tmpd/mytest/mytext.zip $tmpd/
}

@test "htd clean" {
  cd $tmpd
  run htd clean
}
