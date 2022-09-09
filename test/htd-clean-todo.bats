#!/bin/bash

base=htd\ clean
load init

setup()
{
  init && lib_load setup-sh-tpl &&
  setup_sh_tpl "$" "" "$tmpd"
}


@test "htd-clean/foo" {
  set | grep -i bats >/tmp/bats.env
}


@test "$base " {

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
