#!/usr/bin/env bats

load init
base=oshc-baseline

setup()
{
  init
  # sh_list_calls="$HOME/project/oil/bin/oshc deps"
  lib_load functions
  testf1=test/var/sh-src-1.sh
  testf2=test/var/sh-src-2.sh
  testf3=test/var/sh-src-3.sh
  testf4=test/var/sh-src-4.sh
  testf5=test/var/sh-src-5.sh
  testf6=test/var/sh-src-6.sh
  testf7=test/var/sh-src-7.sh
  testf8=test/var/sh-src-8.sh
}

@test "$base: deps --chained-commands" {

  #FIXME: only two chained-command are working:
  #su ls # XXX: bug not working regardless of args, exec exists (even with $PATH)
  #bash exec_bash # XXX: Idem as su
  #sh ./exec_sh # Idem again
  #exec my-exec
  #strace my-strace

  run list_sh_calls "$testf1"
  { test_ok_nonempty 1 && test_lines "printf" ; } || stdfail 1.
  run list_sh_calls "$testf2"
  test_ok_empty || stdfail 2.
  run list_sh_calls "$testf3"
  test_ok_empty || stdfail 3.
  run list_sh_calls "$testf4"
  test_ok_empty || stdfail 4.
  run list_sh_calls "$testf5"
  { test_ok_nonempty 1 && test_lines "cat" ; } || stdfail 5.
  run list_sh_calls "$testf6" 
  # FIXME: only outputs echo on chained-command?
  { test_ok_nonempty 2 && test_lines "sudo" "echo" ; } || stdfail 6.
  run list_sh_calls "$testf7"
  { test_ok_nonempty 2 && test_lines "pr" "seq"; } || stdfail 7.
  run list_sh_calls "$testf8"
  { test_ok_nonempty 1 && test_lines "cat" ; } || stdfail 8.
}
