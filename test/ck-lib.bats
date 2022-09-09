#!/usr/bin/env bats

base=ck.lib
load init

setup()
{
  init && lib_load ck ck-htd
}

testf1=test/var/os/nix_comments.txt
testf2=test/var/os/empty.file


@test "$base: ck-git FILE [CHECK]" {

load extra
load stdtest
load assert

  run ck_git ""
  { test_nok_nonempty && test_lines "*fatal*"
  } || stdfail A.

  run ck_git "$testf1"
  { test_ok_nonempty 1 && test_lines "02cf30c01309f4f5fee566ebad97397c347aebab"
  } || stdfail B.

  run ck_git "$testf2"
  { test_ok_nonempty 1 && test_lines "$empty_git"
  } || stdfail C.
}

@test "$base: ck-md5 FILE [CHECK]" {

load extra
load stdtest
load assert

  run ck_md5 ""
  test_nok_nonempty || stdfail A.

  run ck_md5 "$testf1"
  { test_ok_nonempty 1 && test_lines "02cf30c01309f4f5fee566ebad97397c347aebab"
  } || stdfail B.

  run ck_md5 "$testf2"
  { test_ok_nonempty 1 && test_lines "$empty_md5"
  } || stdfail C.
}

@test "$base: ck-sha1 FILE [CHECK]" {

load extra
load stdtest
load assert

  run ck_sha1 ""
  test_nok_nonempty || stdfail A.

  run ck_sha1 "$testf1"
  { test_ok_nonempty 1 && test_lines "02cf30c01309f4f5fee566ebad97397c347aebab"
  } || stdfail B.

  run ck_sha1 "$testf2"
  { test_ok_nonempty 1 && test_lines "$empty_sha1"
  } || stdfail C.
}

@test "$base: ck-sha2 FILE [CHECK]" {

load extra
load stdtest
load assert

  run ck_sha2 ""
  test_nok_nonempty || stdfail A.

  run ck_sha2 "$testf1"
  { test_ok_nonempty 1 && test_lines "02cf30c01309f4f5fee566ebad97397c347aebab"
  } || stdfail B.

  run ck_sha2 "$testf2"
  { test_ok_nonempty 1 && test_lines "$empty_sha2"
  } || stdfail C.
}
