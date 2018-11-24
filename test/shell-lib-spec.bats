#!/usr/bin/env bats

load init
base=shell.lib

setup()
{
  init &&
  lib_load shell
}


# Test shell.lib.sh functions for detecting Sh-variants based on bi/sbi/a/bin.
# See inline docs, <docs/shell-builtis> and <U_S:doc/shell.md>


@test "$base: lib loads" {

  run test -n "$SHELL_NAME"
  test_ok_empty || stdfail "1: Sh-Name: $SHELL_NAME"

  run test -n "$SD_SHELL_DIR"
  test_ok_empty || stdfail "2: Dir to record env-keys snapshots: $SD_SHELL_DIR"
}


@test "$base: shell-init (calls shell-check, shell-test-sh and sh-env-init)" {

# run in proper test-harnass first, then look at function/local-env
  run shell_init
  test_ok_empty || stdfail 1.

  _r() { shell_init && test -n "$BA_SHELL" -a -n "$IS_BASH_SH"; }
  run _r
  test_ok_empty || stdfail 2.a.

  _r() { shell_init && test -n "$HEIR_SH" -a -n "$IS_HEIR_SH"; }
  run _r
  test_ok_empty || stdfail 2.b.
}


@test "$base: shell-init (II - vars)" {
  load assert

# Quickly go through the env
  assert func_exists shell_init
  assert func_exists sh_init_mode
  assert func_exists sh_env_init
  assert func_exists shell_test_sh
  assert func_exists sh_aliasinfo
  assert func_exists sh_execinfo

  shell_init
  assert func_exists sh_env
  assert func_exists sh_isset
  assert test -n "$SHELL_NAME"
  assert test -n "$B_SHELL"
  assert test -n "$BA_SHELL"
  assert test -n "$A_SHELL"
  assert test -n "$D_A_SHELL"
  # TODO: See what other shells have Sh-Mode, start using SHELL_NAME and
  # SHELL_TYPE maybe to subcategorize Bash, Oil and other type shells.
  # XXX: what about other names. Use SHELL_NAME?
  # TODO: test -n "$A_NAME" for almq.?
  # TODO: test -n "$ALMQUIST_NAME"
  # TODO: test -n "$OIL_NAME" for oil-shell?
  assert test -n "$KORN_SHELL"

  # Sh-mode checks
  assert test -n "$IS_BASH_SH"
  assert test -n "$IS_DASH_SH"
  assert test -n "$IS_BB_SH"
  #test -n "$IS_Z_SH" TODO: See what other shells are/have Sh-Mode
  #test -n "$IS_OIL_SH"
  #test -n "$IS_FISH_SH"
  #test -n "$IS_POSH_SH"
  #test -n "$IS_YASH_SH"
  assert test -n "$IS_HEIR_SH"
  assert test $IS_BASH -eq 1
}


@test "$base: env (after shell-init)" {

  shell_init
# NOTE: built tests with Bats for Bourne-Again shells, so fail otherwise every
# time
  test $IS_BASH -eq 1
}


@test "$base: sh-is-type-a (Bash can expand aliases in scripts)" {
  shell_init

  _r() {
    shopt -s expand_aliases
    alias foo='bar'
    sh_is_type_a foo
  }
  run _r
  test_ok_empty || stdfail "alias foo=bar"

# Idem. ditto, see $base: env
  test $IS_BASH -eq 1
}


@test "$base: sh-aliasinfo tells the aliased cmd-line (Bash)" {

  shell_init
  shopt -s expand_aliases
  alias foo='baz $EDITOR xxx "$@"'
  alias bar='foo bar'

  _r() { sh_execinfo "$@"; }
  
  run _r foo
  { test_ok_nonempty 1 && test_lines 'a:baz $EDITOR xxx "$@"'
  } || stdfail "alias foo"

  run _r foo bar
  { test_ok_nonempty 2 && test_lines 'a:foo:baz $EDITOR xxx "$@"' 'a:bar:foo bar'
  } || stdfail "alias foo bar"

# Idem. ditto, see $base: env
  test $IS_BASH -eq 1
}


@test "$base: sh-execinfo tells the CMD type (Bash)" {

  shell_init

# Bash has no aliases or special built-ins reported for sh-mode

  run sh_execinfo "ls"
  { test_ok_nonempty 1 && test_lines "bin:/bin/ls" ;} || stdfail "ls"

  run sh_execinfo "alias"
  { test_ok_nonempty 1 && test_lines "bi" ;} || stdfail "alias"

  run sh_execinfo "true"
  { test_ok_nonempty 1 && test_lines "bi" ;} || stdfail "true"

# Multiple cmds produce per-cmd output

  run sh_execinfo "break" "test" "false"
  { test_ok_nonempty 3 && test_lines "bi:break" "bi:test" "bi:false"
  } || stdfail "test"

# Wraps sh-aliasinfo correctly

  alias foo='bar xyz' 
  shopt -s expand_aliases
  run sh_execinfo foo
  { test_ok_nonempty 1 && test_lines "a:bar xyz" ;} || stdfail "alias foo"

# Ditto, see $base: env
  test $IS_BASH -eq 1
}


@test "$base: sh-env is defined after sh-env-init and includes local 'env' util" {
  shell_init

  run sh_env
  { test_ok_nonempty && test_lines 'PATH=*' 'BATS*'
  } || stdfail "$(sh_env)"
}


@test "$base: sh-isset detects local var name" {
  load assert
  shell_init

  # Normal env in two different test harnasses:

  run sh_isset PATH
  test_ok_empty || stdfail PATH

  assert test -n "$PATH"
  assert sh_isset PATH

  # Test local vars

  refute sh_isset foo
  refute sh_isset bar
  refute sh_isset abcdefxyz
  foo=
  bar=

  assert sh_isset foo # Local var detected OK
  assert test -z "$foo"

  run sh_isset foo
  test_ok_empty || stdfail foo # Local env OK

  run bash -c 'test -n "$foo"'
  test_nok_empty || stdfail subshell-foo-var # Not exported

  run sh_isset abcdefxyz
  test_nok_empty || stdfail abcdefxyz # Not set
}


@test "$base: sh-isenv detects exported vars like sh-isset" {
  load assert
  shell_init

  assert sh_isenv PATH
  refute sh_isenv abcdefxyz
  foo=
  refute sh_isenv foo
}
