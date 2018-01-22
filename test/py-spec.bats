#!/usr/bin/env bats

load helper


setup()
{
  # non-zero exit for $py -h basenames
  r_calendartable=1
  r_schema_test=1
  r_fchardet=1
  r_dtd2dot=1
  r_domain1=1
  r_filesize_frequency=1
  r_treemap=1
  # skip these (py) executables
  x_mkdocs=1 # FIXME: mkdocs
}

get_py_files()
{
  git ls-files | { while read x
    do
      case "$x" in

        # Filter filenames to (executable) python scripts
        *.py ) test -x "$x" || false ;;
        *.* ) continue ;;
        * )
            test -f "$x" -o -h "$x" || continue
            test -s "$x" && {
              head -n 1 "$x" | grep -q '#\!.*\/usr.bin.env\ py' || false
            } || false
          ;;
      esac && echo "$x" || { test -z "$DEBUG" || diag "Skipped '$x'"; }
    done
  }
}

@test "Test all python scripts with main entry are executable" {

  local nok=0 keep_going=
  test -z "$DEBUG" || keep_going=1
  get_py_files | { while read x ; do bn="$(basename "$x" .py)"

    grep -q '__name__.*==.*__main__' $x || continue
    test -x "$x" || fail "Script $bn has main entry but is not executable"

    test 0 -eq $nok -o -n "$keep_going" || return $nok
  done ; test 0 -eq $nok || return $?; }
}

@test "Test all executable python scripts are behaving" {

  for x in ./*.py
  do
    test -x "$x" || continue
    bn="$(basename "$x" .py | tr -sc 'A-Za-z0-9_\n' '_' )"
    
    # Skip ignored
    test "1" = "$(eval echo \"\$x_$bn\")" && continue

    ./$x -h >/dev/null 2>&1 || { r=$?

      # continue still if non-zero matches expected
      test "$r" = "$(eval echo \"\$r_$bn\")" && continue

      fail "$x $r"
    }
    test ! -e "./-h" || {
      fail "$x created ./-h"
    }
  done

  test "$uname" != "Linux" || {
    python ./linux-network-interface-cards.py
  }
}

# FIXME: seems to be skipping some cases
@test "Test all executable python scripts are behaving (II)" {

  local nok=0 keep_going=
  test -z "$DEBUG" || keep_going=1
  get_py_files | { while read x ; do bn="$(basename "$x" .py | tr -sc 'A-Za-z0-9_\n' '_' )"

    { $x -h || { r=$?

      # continue still if non-zero matches expected
      test "$r" = "$(eval echo \"\$r_$bn\")" && diag "Passed $bn" || {

        diag "Failure at '$bn' ($r)"
        export nok=$r
      }
    } ; } >/dev/null 2>&1 

    test 0 -eq $nok -o -n "$keep_going" || return $nok
  done ; test 0 -eq $nok || return $?; }
}


