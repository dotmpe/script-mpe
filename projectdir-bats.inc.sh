
pd_register bats check test


pd__bats_autoconfig()
{
  test -x "$(which bats 2>/dev/null)" || return 1
  test "$(echo test/*-spec.bats)" != "test/*-spec.bats" \
    || return $?
}

pd_check__bats_autoconfig()
{
  pd__bats_autoconfig && {
    note "Using Bats"
    echo :bats:specs
  } || return 0
}

pd_test__bats_autoconfig()
{
  pd__bats_autoconfig && {
    note "Using Bats"
    echo :bats
  } || return 0
}

#pd_trgtpref__bats_count=bats:count
#pd_stat__bats_count=bats/count

pd_glob__bats_files='./test/*-spec.bats'
pd_trgtpref__bats_files=bats:file


# Expand to files
#   default glob to test files, or
#   replace globstar with given argument if file exists, or
#   give an error.
#
#   Filter prefixed arguments unless prefix bats:file, strip that one.
#
pd_bats_files_args()
{

  test -n "$pd_trgtglob" \
    || pd_trgtglob="$(eval echo "\"\$$(try_local "bats-files" glob)\"")"

  {
    test -n "$1" && {

      test -n "$pd_trgtpref" \
        || pd_trgtpref="$(eval echo "\"\$$(try_local "$subcmd" trgtpref)\"")"

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

      local retry=$(setup_tmpf .retry "$subcmd-$PWD")
      test -e "$retry" && {
        note "Using targets from retry file ($(count_lines $retry))"
        cat $retry | sed 's/^bats://g'
        rm $retry
      } || {

        echo $pd_trgtglob | words_to_lines | while read target
        do
          echo "$target"
        done
      }
    }
  } | words_to_lines > $arguments
}


pd_load__bats_files=iIa
pd__bats_files()
{
  cat $arguments
}
pd_defargs__bats_files=pd_bats_files_args


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


pd_man_1__bats_specs="List tests from Bats files. Fail on missing or invalid files. "
pd_spc__bats_specs="[ file | name | file:name | file:index ]..."
pd__bats_specs()
{
  set -- $(cat $arguments)
  pd__bats_load
  local file_count=0 test_count=0
  for arg in $@
  do
    local tests="$( { verbosity=0; bats-exec-test -l "$arg" || {
      errored "$subcmd:$arg";
    };} | lines_to_words )"
    test -z "$tests" || {
      incr file_count
      echo $tests | words_to_lines | sed 's#^#'$subcmd:$arg':#' >$passed
      incr test_count $(echo "$tests" | count_words)
    }
  done
  test $test_count -gt 0 \
    && {
      values="files=$file_count tests=$test_count"
      note "$test_count tests, in $file_count files OK"
    } || {
      warn "No Bats files loaded"
      failed "$subcmd:$@"
    }
  export values
}
pd_load__bats_specs=iIa
pd_defargs__bats_specs=pd_bats_files_args



pd_man_1__bats_count="List Bats files and count tests. Fail on missing or invalid count. "
pd_spc__bats_count="[ BATS ]..."
pd__bats_count()
{
  set -- $(cat $arguments)
  set_bats_bin_path
  local count=0 specs=0

  for x in $@
  do
    local s=$(verbosity=0; bats-exec-test -c "$x" && {
      passed $subcmd:$x
    } || {
      errored $subcmd:$x
    })
    test -z "$s" || {
      incr count
      incr specs $s
    }
  done

  values="bats/count=$count bats/tests=$specs"

  test $count -gt 0 \
    && {
      note "$specs tests, in $count count OK"
    } || {
      warn "No Bats count found"
      failed "$subcmd:$@"
    }
}
pd_load__bats_count=igaI
pd_defargs__bats_count=pd_bats_files_args
pd_stat__bats_count=bats/count


pd_load__bats=iIa
pd__bats()
{
  local argc=$# curarg=0
  for x in $@
  do
    incr curarg
    {
      echo "# Bats $curarg of $argc ($x)"
      verbosity=6 bats $x \
        || echo "bats:$x" >>$failed
    } | bats-color.sh
  done

  test -s "$failed" && {
    cp $failed $(setup_tmpf .retry "$subcmd-$PWD")
    return 1
  }

  return 0
}
pd_defargs__bats=pd_bats_files_args


