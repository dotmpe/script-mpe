#!/usr/bin/env bats

base=match.sh
load init
init

setup()
{
  . $scriptpath/match.lib.sh
}


@test "${base}: no arguments no-op" {
  run ${bin}
  test $status -eq 1
  fnmatch "*match.*Error*No command given*" "${lines[*]}"
}

@test "${base}: no arguments no-op (plain)" {
  run ${bin}
  #echo "${lines[*]}" > /tmp/1
  test $status -eq 1
  #simza: /Users/berend/bin/std.sh: line 90: [match.sh] Error: No command given, see "help": command not found
  #test "${lines[0]}" = "[match.sh] Error: No command given, see \"help\"" || TODO "should some colorless terminal?"
}

@test "${base}: help" {
  run ${bin} help
  test ${status} -eq 0
  fnmatch "*Usage:*" "${lines[*]}" # usage info on out
#  fnmatch "*Commands:*" "${lines[*]}" # detailed usage on out
  fnmatch "*Error:*" "${lines[*]}" && test -z "errors in output" || true
}

@test "${base}: -h" {
  run ${bin} -h
  test ${status} -eq 0
  fnmatch "*Usage:*" "${lines[*]}" # usage info on out
# FIXME  fnmatch "*Commands:*" "${lines[*]}" # detailed usage on out
  fnmatch "*Error:*" "${lines[*]}" && test -z "errors in output" || true
}

@test "${base}: -h help" {
  run ${bin} -h help
  test ${status} -eq 0
  fnmatch "*Help 'help':*" "${lines[*]}" # manual on out
  fnmatch "*Usage: * match -h|help \[ID]*" "${lines[*]}" # usage info on out
  fnmatch "*Error:*" "${lines[*]}" && test -z "errors in output" || true
}

@test "${base}: help help" {
  run ${bin} help help
  test_ok_lines \
      "Usage:*" \
          "*match -h|help \[ID]" \
      "Help 'help':*" \
          || stdfail
}

@test "${base}: glob matches path" {

  silent=1
  # FIXME: silent -s
  run ${bin} glob 'test.*' test.name
  { test $status -eq 0 &&
    test -z "${lines[*]}"
  } || stdfail 1

  run ${bin} glob '*.name' test.name
  { test $status -eq 0 &&
    test -z "${lines[*]}"
  } || stdfail 2

  run ${bin} glob '*.*' test.name
  { test $status -eq 0 &&
    test -z "${lines[*]}"
  } || stdfail 3

  run ${bin} glob 'path/.*.ext' path/.name.ext
  { test $status -eq 0 &&
    test -z "${lines[*]}"
  } || stdfail 4

  run ${bin} glob './path/.*.ext' ./path/.name.ext
  { test $status -eq 0 &&
    test -z "${lines[*]}"
  } || stdfail 5
}

word_diff()
{
  tmpf
  f1=$tmpf
  tmpf
  f2=$tmpf
  echo  "$1" | tr ' ' '\n' > $f1
  echo  "$2" | tr ' ' '\n' > $f2
  echo "Differences, result:"
  echo "  $1"
  echo "Versus expected:"
  echo "  $2"
  echo "Changes:"
  diff $f1 $f2
}

@test "${base}: lists var names" {
  check_skipped_envs travis || skip "FIXME names"
  # FIXME --silent alias run ${bin} -s var-names
  #run ${bin} --silent var-names
  silent=1
  run ${bin} var-names
  test $status -eq 0
  vars="ALPHA CK_CKS DOMAIN EXT IDCHAR IDCHARS MD5_CKS NAMECHARS NAMEDOTPARTS NAMEPART NUM OPTPART PART SHA1_CKS SZ"
  test "${lines[0]}" = "$vars" \
    || fail "Vars mismatch: $(word_diff "${lines[0]}" "$vars")"
}

# TODO: test wether named patterns still exists, and notice any out-of-date testcase

@test "${base}: lists var names in name pattern" {
  run match.sh name-pattern-opts ./@NAMEPART.@SHA1_CKS.@EXT
  {
    test $status -eq 0 &&
    test "${lines[0]}" = "EXT" &&
    test "${lines[1]}" = "NAMEPART" &&
    test "${lines[2]}" = "SHA1_CKS" &&
    test "$(echo ${lines[@]})" = "EXT NAMEPART SHA1_CKS"
  } || fail "Unexpected output: '${lines[*]}'"
}
