#!/usr/bin/env bats

load init
base=mkvar.lib
  
testf1=test/var/mkvar/test1.kv
testf1b=test/var/mkvar/test1b.kv
testf1c=test/var/mkvar/test1c.kv
testf1d=test/var/mkvar/test1d.kv
testf2=test/var/mkvar/test2.kv
testf3=test/var/mkvar/test3.kv

setup()
{
  init && lib_load make mkvar
}


@test "$base: " {

  _r() { mkvar_sh < "$1"; }

  run _r "$testf1"
  test_ok_nonempty 5 || stdfail 1.
  
  run _r "$testf1b"
  test_ok_nonempty 5 || stdfail 2.
  
  run _r "$testf1c"
  test_ok_nonempty 3 || stdfail 3.
  
  run _r "$testf1d"
  test_ok_nonempty 4 || stdfail 4.
  
  run _r "$testf2"
  test_ok_nonempty 9 || stdfail 5.
  
  run _r "$testf3"
  test_ok_nonempty 1 || stdfail 6.
}
