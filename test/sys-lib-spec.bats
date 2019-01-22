#!/usr/bin/env bats

base=sys.lib
load init

setup()
{
  init "" 0 && lib_load sys &&
  main_inc=$SHT_PWD/var/sh-src-main-mytest-funcs.sh
}


@test "$base: incr VAR [AMOUNT]" {

  load stdtest

  COUNT=2
  run incr COUNT 5
  test_ok_empty || stdfail "1."

  incr COUNT 5
  test $COUNT -eq 7 || stdfail "2. ($COUNT)"

}


@test "$base: trueish VALUE" {

  load extra stdtest
  run trueish 1 ; test_ok_empty || stdfail 1.A.
  run trueish 0 ; test_nok_empty || stdfail 1.B.

  run trueish True ; test_ok_empty || stdfail 2.A.
  run trueish False ; test_nok_empty || stdfail 2.B.

  run trueish On ; test_ok_empty || stdfail 3.A.
  run trueish Off ; test_nok_empty || stdfail 3.B.

  run trueish Yes ; test_ok_empty || stdfail 4.A.
  run trueish No ; test_nok_empty || stdfail 4.B.

  run trueish - ; test_nok_empty || stdfail 5.A.
  run trueish "" ; test_nok_empty || stdfail 5.B.

}

@test "$base: not-trueish VALUE" {

  load extra stdtest
  run not_trueish 1 ; test_nok_empty || stdfail 1.A.
  run not_trueish 0 ; test_ok_empty || stdfail 1.B.

  run not_trueish True ; test_nok_empty || stdfail 2.A.
  run not_trueish False ; test_ok_empty || stdfail 2.B.

  run not_trueish On ; test_nok_empty || stdfail 3.A.
  run not_trueish Off ; test_ok_empty || stdfail 3.B.

  run not_trueish Yes ; test_nok_empty || stdfail 4.A.
  run not_trueish No ; test_ok_empty || stdfail 4.B.

  run not_trueish - ; test_ok_empty || stdfail 5.A.
  run not_trueish "" ; test_ok_empty || stdfail 5.B.

}

@test "$base: falseish VALUE" {

  load stdtest
  run falseish 1 ; test_nok_empty || stdfail 1.A.
  run falseish 0 ; test_ok_empty || stdfail 1.B.

  run falseish True ; test_nok_empty || stdfail 2.A.
  run falseish False ; test_ok_empty || stdfail 2.B.

  run falseish On ; test_nok_empty || stdfail 3.A.
  run falseish Off ; test_ok_empty || stdfail 3.B.

  run falseish Yes ; test_nok_empty || stdfail 4.A.
  run falseish No ; test_ok_empty || stdfail 4.B.

  run falseish - ; test_nok_empty || stdfail 5.A.
  run falseish "" ; test_nok_empty || stdfail 5.B.

}

@test "$base: not-falseish VALUE" {

  load stdtest
  run not_falseish 1 ; test_ok_empty || stdfail 1.A.
  run not_falseish 0 ; test_nok_empty || stdfail 1.B.

  run not_falseish True ; test_ok_empty || stdfail 2.A.
  run not_falseish False ; test_nok_empty || stdfail 2.B.

  run not_falseish On ; test_ok_empty || stdfail 3.A.
  run not_falseish Off ; test_nok_empty || stdfail 3.B.

  run not_falseish Yes ; test_ok_empty || stdfail 4.A.
  run not_falseish No ; test_nok_empty || stdfail 4.B.

  run not_falseish - ; test_ok_empty || stdfail 5.A.
  run not_falseish "" ; test_ok_empty || stdfail 5.B.

}


@test "$base: cmd-exists NAME" {

  load stdtest
  run cmd_exists "ls"
  test_ok_empty || stdfail "A."

  run cmd_exists ""
  test_nok_empty || stdfail "B.1."
  
  lib_load os

  run which "$(get_uuid)"
  test_nok_empty || stdfail "B.2."

  run cmd_exists "$(get_uuid)"
  test_nok_empty || stdfail "B.3."

}


@test "$base: func-exists NAME" {

  load stdtest extra
  myfunc() { false; }

  run func_exists myfunc
  test_ok_empty || stdfail A.

  lib_load os

  run func_exists $(get_uuid)
  test_nok_empty || stdfail B.
}


# util / Try-Exec

@test "$base: try-exec-func on existing function" {

  load stdtest extra
  . $main_inc

  export verbosity=4

  run try_exec_func mytest_function
  test "$USER" = "travis" && skip "FIXME log"
  { test $status -eq 0 && fnmatch "mytest" "${lines[*]}"
  } || stdfail

}

@test "$base: try-exec-func on non-existing function" {

  run try_exec_func no_such_function
  test $status -eq 1

}


@test "$base: try-exec-func (bash) on existing function" {

  run bash -c "$(cat <<EOM

source $scriptpath/tools/sh/init.sh &&
lib_load &&
source '$main_inc' &&
try_exec_func mytest_function
EOM
    )"
  diag "Output: ${lines[0]}"
  {
    test $status -eq 0 &&
    fnmatch "mytest" "${lines[*]}"
  } || stdfail 3.
}

@test "$base: try-exec-func (bash) on non-existing function" {

  export verbosity=6
  lib_load sys

  run bash -c "$( cat <<EOM
# source '$scriptpath'/tools/sh/init-wrapper.sh && try_exec_func no_such_function
source '$scriptpath'/tools/sh/init.sh && lib_load && try_exec_func no_such_function
EOM
    )"
  #run bash -c 'scriptpath='$lib' && util_mode=boot source '$lib'/util.sh && try_exec_func no_such_function'
  { test "" = "${lines[*]}" && test $status -eq 1
  } || stdfail 4.1.1

  export verbosity=7
  run bash -c "$( cat <<EOM
export scriptpath='$scriptpath'
util_mode=boot source '$scriptpath'/tools/sh/init-wrapper.sh && try_exec_func no_such_function
EOM
)"
  {
    fnmatch "*try-exec-func 'no_such_function'*" "${lines[*]}" &&
    test $status -eq 1
  } || stdfail 4.1.2

  export verbosity=6
  run bash -c 'type no_such_function'
  {
    test "bash: line 0: type: no_such_function: not found" = "${lines[0]}" &&
    test $status -eq 1
  } || stdfail 4.2
}

@test "$base: try-exec-func (sh) on existing function" {

  lib_load sys
  export verbosity=5
  run sh -c 'TERM=dumb && scriptpath='$scriptpath' && util_mode=boot . '$scriptpath'/tools/sh/init-wrapper.sh && \
    . '$main_inc' && try_exec_func mytest_function'
  {
    test -n "${lines[*]}" &&
    test "${lines[0]}" = "mytest" &&
    test $status -eq 0
  } || stdfail
}

@test "$base: try-exec-func (sh) on non-existing function" {

  lib_load sys
  export verbosity=5

  run sh -c 'TERM=dumb && scriptpath='$scriptpath' && util_mode=boot . '$scriptpath'/tools/sh/init-wrapper.sh && try_exec_func no_such_function'
  test "" = "${lines[*]}" || stdfail 1

  case "$(uname)" in
    Darwin )
      test $status -eq 1
      ;;
    Linux )
      test $status -eq 127
      ;;
  esac

  run sh -c 'type no_such_function'
  case "$(uname)" in
    Darwin )
      test "sh: line 0: type: no_such_function: not found" = "${lines[0]}"
      test $status -eq 1
      ;;
    Linux )
      test "no_such_function: not found" = "${lines[0]}"
      test $status -eq 127
      ;;
  esac
}


@test "${base}: capture CMD captures subshell return status to var while redirecting output" {

  lib_load sys os
  run capture true '' '' '' "foo"
  test_ok_empty || stdfail 1.1.
  run capture false '' '' '' "bar" "baz"
  test_ok_empty || stdfail 1.2.

  load extra
  tmpf ; out_file=$tmpf ; __test__() {
     ret_var=
     capture ls '' 'out_file' ''  -la
     echo "ret_var=$ret_var"
     echo "out_file=$out_file"
  }
  run __test__
  { test_ok_nonempty 2 && test_lines "ret_var=0" "out_file=$tmpf" &&
    grep '\<ReadMe\.rst\>' "$tmpf" && 
    rm "$out_file" &&  unset tmpf out_file
  } || stdfail 2.
}


@test "${base}: capture CMD handles command pipeline input as well" {

  load extra
  lib_load os
  tmpf ; input=$tmpf
  tmpf ; out_file=$tmpf
  __test__() {
     ret_var=
     echo some input >"$input"
     capture cat 'ret_var' 'out_file' "$input"
     echo "ret_var=$ret_var"
     echo "out_file=$out_file"
  }
  run __test__
  { test_ok_nonempty 2 && test_lines "ret_var=0" "out_file=$tmpf" &&
    grep '^some input$' "$tmpf" && rm "$input" "$out_file" &&
     unset input out_file tmpf
  } || stdfail 'A'
}


@test "${base}: capture-var or eval cmd-string" {

  lib_load std sys os
  func_exists capture_var
  my_cmd()
  {
    echo "${1}2ab"
  }

  # Test all args
  pref= set_always= capture_var my_cmd ret out 1
  { test "$out" = "12ab" && test "$ret" = "0" && unset out ret
  } || stdfail "1: out-var: $out, ret-var: $ret"

  # Test default out
  pref= set_always= capture_var my_cmd ret "" 2
  { test "$my_cmd" = "22ab" && test "$ret" = "0"
    # && unset my_cmd ret
  } || stdfail "2: out-var: $my_cmd, ret-var: $ret"

  # Test eval
  pref=eval set_always= capture_var 'my_cmd "$@" | cat -' ret out 3
  { test "$out" = "32ab" && test "$ret" = "0" && unset out ret
  } || stdfail "3: out-var: $out, ret-var: $ret"
}


# Sync: U-S:test/unit/sys-lib.bats
# Id: script-mpe/0.0.4-dev test/sys-lib-spec.bats
