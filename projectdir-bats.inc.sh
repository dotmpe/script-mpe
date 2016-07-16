
pd_register bats check test


pd_check__bats_autoconfig()
{
  echo bats:specs
}

pd_test__bats_autoconfig()
{
  echo bats
}


pd_glob__bats_files='./test/*-spec.bats'
pd_trgtpref__bats_files=bats:file


# Expand to files
#   default glob to test files, or
#   replace globstar with given argument if file exists, or
#   give an error.
#
#   Filter prefixed arguments unless prefix bats:file, strip that one.
#
pd_load__bats_files=iI
pd__bats_files()
{
  test -n "$pd_trgtglob" \
    || pd_trgtglob="$(eval echo "\"\$$(try_local "$subcmd" glob)\"")"

  test -n "$1" && {

    test -n "$pd_trgtpref" \
      || pd_trgtpref="$(eval echo "\"\$$(try_local "$subcmd" trgtpref)\"")"
    set -f
    set -- $(pd_filter_args $pd_trgtpref "$@")
    set +f

    while test -n "$1"
    do
      set -f
      for glob in $pd_trgtglob
      do
        set +f

        target_globs="$(echo "$glob" | sed 's#\*#'$1'#')"
        targets="$(for target in $target_globs
          do
            test -e "$target" && {
              echo "$target"
            }
          done)"

        test -n "$targets" && {
          echo "$targets" | words_to_lines
        } || {
          test -e "$1" && {
            echo $1 | sed 's/^bats:file://g'
          }
        }

        set -f
      done
      set +f

      shift
    done

  } || {

    for target in $pd_trgtglob
    do
      echo "$target"
    done
  }
}


# glob-names: use glob to find all shorter names
pd_load__bats_gnames=iI
pd__bats_gnames()
{
  test -n "$pd_trgtglob" \
    || pd_trgtglob="$(eval echo "\"\$$(try_local bats-files glob)\"")"
  pd_globstar_names "$pd_trgtglob" "$@"
}


# Expand to tests using pd__bats_files,
# emit skip for files without tests, or fail for invalid files
# pass name args to pd__bats_files, or use as function fnmatch
pd__bats_test_args()
{
  pd__bats_load
}


pd__bats_load()
{
  test -n "$bats_bin" || set_bats_bin_path
}

set_bats_bin_path()
{
  # Get path to bats libexec's
  bats_bin=$(which bats)
  while test -h "$bats_bin"; do bats_bin="$(realpath "$bats_bin")"; done

  local PREFIX="$(dirname "$(dirname "$bats_bin")")"
  # FIXME: still needed at travis?
  case "$(whoami)" in
    travis )
        export PATH=$PATH:$HOME/.local/libexec/
      ;;
    * )
        export PATH=$PATH:$PREFIX/libexec/
      ;;
  esac
  unset PREFIX
}


pd_man_1__bats_tests="List tests from Bats files. Fail on missing or invalid files. "
pd_spc__bats_tests="[ file | name | file:name | file:index ]..."
pd_load__bats_tests=iaI
pd__bats_tests()
{
  set -- $(cat $arguments)
  pd__bats_load
  local file_count=0 test_count=0
  for arg in $@
  do
    local tests="$( { verbosity=0; bats-exec-test -l "$arg" || {
      errored "$pd_trgtpref:$arg";
    };} | lines_to_words )"
    test -z "$tests" || {
      incr file_count
      echo $tests | words_to_lines | sed 's#^#'$pd_trgtpref:$arg':#' | passed
      incr test_count $(echo "$tests" | count_words)
    }
  done
  test $test_count -gt 0 \
    && {
      note "$test_count tests, in $file_count files OK"
    } || {
      warn "No Bats files loaded"
      failed "$pd_trgtpref:$@"
    }
}
pd_trgtpref__bats_tests=bats:tests
pd_stat__bats_tests=bats/tests
pd_defargs__bats_tests=pd__bats_files



pd_man_1__bats_count="List Bats files and count tests. Fail on missing or invalid count. "
pd_spc__bats_count="[BATS]..."
pd_load__bats_count=aigI
pd__bats_count()
{
  set -- $(cat $arguments)
  set_bats_bin_path
  local count=0 specs=0

  for x in $@
  do
    local s=$(verbosity=0; bats-exec-test -c "$x" && {
      passed $pd_trgtpref:$x
    } || {
      errored $pd_trgtpref:$x
    })
    test -z "$s" || {
      incr count
      incr specs $s
    }
  done

  states="bats/count=$count bats/tests=$specs"

  test $count -gt 0 \
    && {
      note "$specs tests, in $count count OK"
    } || {
      warn "No Bats count found"
      failed "$pd_trgtpref:$@"
    }
}
pd_trgtpref__bats_count=bats:count
pd_stat__bats_count=bats/count


#pd_load__bats=iI
pd__bats()
{
  test -n "$1"

  status_key=bats
  local_target=$(echo $1 | cut -c 6-)
  export $(hostname -s | tr 'a-z.-' 'A-Z__')_SKIP=1
  {
    bats $local_target.bats || return $?
  } | bats-color.sh


  status_key=bats
  export $(hostname -s | tr 'a-z.-' 'A-Z__')_SKIP=1
  {
    verbosity=6 ./test/*-spec.bats || return $?
  } | bats-color.sh

  #for x in ./test/*-spec.bats;
  #do
  #  bats $x || echo bats:$x >&6
  #done
}

