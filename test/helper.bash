#!/bin/bash


# Add fallbacks for non-std BATS functions

type fail >/dev/null 2>&1 || {
  fail()
  {
    test -z "$1" || echo "Reason: $1" >> $BATS_OUT
    exit 1
  }
}

type diag >/dev/null 2>&1 || {
  # Note: without failing test, output will not show up in std Bats install
  diag()
  {
    BATS_TEST_DIAGNOSTICS=1
    echo "$1" >>"$BATS_OUT"
  }
}

type TODO >/dev/null 2>&1 || { # tasks:no-check
  TODO() # tasks:no-check
  {
    test -n "$TODO_IS_FAILURE" && {
      ( 
          test -z "$1" &&
              "TODO ($BATS_TEST_DESCRIPTION)" || echo "TODO: $1"  # tasks:no-check
      )>> $BATS_OUT
      exit 1
    } || {
      # Treat as skip
      BATS_TEST_TODO=${1:-1}
      BATS_TEST_COMPLETED=1
      exit 0
    }
  }
}

type stdfail >/dev/null 2>&1 || {
  stdfail()
  {
    test -n "$1" || set -- "Unexpected. Status"
    fail "$1: $status, output(${#lines[@]}) is '${lines[*]}'"
  }
}

type pass >/dev/null 2>&1 || {
  pass() # a noop() variant..
  {
    return 0
  }
}

type test_ok_empty >/dev/null 2>&1 || {
  test_ok_empty()
  {
    test ${status} -eq 0 && test -z "${lines[*]}"
  }
}

type test_nok_empty >/dev/null 2>&1 || {
  test_nok_empty()
  {
    test ${status} -ne 0 && test -z "${lines[*]}"
  }
}

type test_nonempty >/dev/null 2>&1 || {
  test_nonempty()
  {
    test -n "${lines[*]}" || return $?
    for match in "$@"
    do
        case "$match" in

          # Test line-count if number given
          "[0-9]"* ) test "${#lines[*]}" = "$1"  || return $? ;;

          # Each match applies to entire line list otherwise
          * ) fnmatch "$1" "${lines[*]}" || return $? ;;

        esac
    done
  }
}

type test_ok_nonempty >/dev/null 2>&1 || {
  test_ok_nonempty()
  {
    test ${status} -eq 0 && test -n "${lines[*]}" && {
      test -n "$*" || return 0
      test_nonempty "$@"
    }
  }
}

type test_nok_nonempty >/dev/null 2>&1 || {
  test_nok_nonempty()
  {
    test ${status} -ne 0 && test -n "${lines[*]}" && {
      test -n "$*" || return 0
      test_nonempty "$@"
    }
  }
}

#type test_lines >/dev/null 2>&1 || {
  test_lines()
  {
    # Each match must be present on a line (given arg order is not significant)
    for match in "$@"
    do
      local v=1 ; for line in "${lines[@]}"
      do
        fnmatch "$match" "$line" && { v=0; break; }
        continue
      done
      test $v -eq 0 || {
        diag "Unmatched '$match'"
        return $v
      }
    done
  }
#}

type test_ok_lines >/dev/null 2>&1 || {
  test_ok_lines()
  {
    test -n "${lines[*]}" || return
    test -n "$*" || return
    test ${status} -eq 0 || return
    test_lines "$@"
  }
}

type test_nok_lines >/dev/null 2>&1 || {
  test_nok_lines()
  {
    test ${status} -ne 0 && test -n "${lines[*]}" && {
      test -n "$*" || return $?
      test_lines "$@"
    }
  }
}

type fnmatch >/dev/null 2>&1 || {
  fnmatch() # Glob Str
  {
    case "$2" in $1 ) return 0 ;; *) return 1 ;; esac
  }
}
