#!/usr/bin/env bats

base=match.sh
load helper
init
. $lib/match.lib.sh



@test "$bin no arguments no-op" {
  run ${bin}
  test $status -eq 1
  fnmatch "*match.*Error*No command given*" "${lines[*]}"
}

@test "$bin no arguments no-op (plain)" {
  run ${bin}
  #echo "${lines[*]}" > /tmp/1
  test $status -eq 1
  #simza: /Users/berend/bin/std.sh: line 90: [match.sh] Error: No command given, see "help": command not found
  test "${lines[0]}" = "[match.sh] Error: No command given, see \"help\"" || skip "TODO should some colorless terminal?"
}

@test "${bin} help" {
  run $BATS_TEST_DESCRIPTION
  test ${status} -eq 0
  fnmatch "*Usage:*" "${lines[*]}" # usage info on out
  fnmatch "*Commands:*" "${lines[*]}" # detailed usage on out
  fnmatch "*Error:*" "${lines[*]}" && test -z "errors in output" || noop
}

@test "${bin} -h" {
  run $BATS_TEST_DESCRIPTION
  test ${status} -eq 0
  fnmatch "*Usage:*" "${lines[*]}" # usage info on out
  fnmatch "*Commands:*" "${lines[*]}" # detailed usage on out
  fnmatch "*Error:*" "${lines[*]}" && test -z "errors in output" || noop
}

@test "${bin} -h help" {
  run $BATS_TEST_DESCRIPTION
  test ${status} -eq 0
  fnmatch "*Help 'help':*" "${lines[*]}" # manual on out
  fnmatch "*Usage: * match -h|help \[<id>]*" "${lines[*]}" # usage info on out
  fnmatch "*Error:*" "${lines[*]}" && test -z "errors in output" || noop
}

@test "${bin} help help" {
  run $BATS_TEST_DESCRIPTION
  test ${status} -eq 0
  fnmatch "*Help 'help':*" "${lines[*]}" # manual on out
  fnmatch "*Usage: * match -h|help \[<id>]*" "${lines[*]}" # usage info on out
  fnmatch "*Error:*" "${lines[*]}" && test -z "errors in output" || noop
}


@test "$bin glob matches path" {
  run ${bin} -s glob 'test.*' test.name
  test $status -eq 0
  test -z "${lines[@]}"
  run ${bin} -s glob '*.name' test.name
  test $status -eq 0
  test -z "${lines[@]}"
  run ${bin} -s glob '*.*' test.name
  test $status -eq 0
  test -z "${lines[@]}"
  run ${bin} -s glob 'path/.*.ext' path/.name.ext
  test $status -eq 0
  test -z "${lines[@]}"
  run ${bin} -s glob './path/.*.ext' ./path/.name.ext
  test $status -eq 0
  test -z "${lines[@]}"
}

@test "$bin lists var names" {
  check_skipped_envs travis || skip "FIXME broken after main.sh rewrite"
  run ${bin} -s var-names
  test $status -eq 0
  vars="SZ SHA1_CKS MD5_CKS CK_CKS EXT NAMECHARS IDCHAR IDCHARS NAMEPART NAMEDOTPARTS ALPHA NUM PART OPTPART DOMAIN"
  test "${lines[0]}" = "$vars"
}

# TODO: test wether named patterns still exists, and notice any out-of-date testcase

@test "$bin lists var names in name pattern" {
  check_skipped_envs travis || skip "FIXME broken after main.sh rewrite"
  source ./match.sh load-ext
  silent=true
  match_load
  run match_name_pattern_opts ./@NAMEPART.@SHA1_CKS.@EXT
  test $status -eq 0
  test "${lines[0]}" = "SHA1_CKS"
  test "${lines[1]}" = "EXT"
  test "${lines[2]}" = "NAMEPART"
  test "$(echo ${lines[@]})" = "SHA1_CKS EXT NAMEPART"
}

@test "$bin compile regex for name pattern" {
  check_skipped_envs travis || skip "FIXME broken after main.sh rewrite"
  source ./match.sh load-ext
  silent=true
  match_load
  match_name_pattern_test ./@NAMEPART.@SHA1_CKS.@EXT
  test $? -eq 0
  test "$grep_pattern" = "\.\/[A-Za-z0-9_,-]\{1,\}\.[a-f0-9]\{40\}\.[a-z0-9]\{2,5\}"
}

@test "$bin compile regex for name pattern (II)" {
  check_skipped_envs travis || skip "FIXME broken after main.sh rewrite"
  source ./match.sh load-ext
  silent=true
  match_load
  match_name_pattern ./@NAMEPART.@SHA1_CKS@OPTPART.@EXT
  test $? -eq 0
  test "$grep_pattern" = "\.\/[A-Za-z0-9_,-]\{1,\}\.[a-f0-9]\{40\}\(\.\(partial\|part\|incomplete\)\)\?\.[a-z0-9]\{2,5\}"
}

@test "$bin compile regex for name pattern (III)" {
  check_skipped_envs travis || skip "FIXME seems requires ~/.conf or something"
  source ./match.sh load-ext
  silent=true
  match_load
  match_name_pattern ./@NAMEPART.@SHA1_CKS@PART.@EXT
  test $? -eq 0
  test "$grep_pattern" = "\.\/[A-Za-z0-9_,-]\{1,\}\.[a-f0-9]\{40\}\.\(partial\|part\|incomplete\)\.[a-z0-9]\{2,5\}"
  match_name_pattern ./@NAMEPART.@SHA1_CKS@PART.@EXT PART
  test $? -eq 0
  test "$grep_pattern" = "\.\/[A-Za-z0-9_,-]\{1,\}\.[a-f0-9]\{40\}\(.\(partial\|part\|incomplete\)\)\.[a-z0-9]\{2,5\}"
}


