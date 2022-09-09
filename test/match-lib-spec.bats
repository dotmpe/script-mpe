#!/usr/bin/env bats

base=match.lib
load init
init
setup()
{
  . $scriptpath/match.lib.sh
}


@test "$base: compile regex for name pattern" {
  check_skipped_envs travis || skip "FIXME broken after main.lib.sh rewrite"
  source ./match.sh load-ext
  source ./match.lib.sh
  silent=true
  match_load
  match__name_pattern_test ./@NAMEPART.@SHA1_CKS.@EXT
  test $? -eq 0
  test "$grep_pattern" = "\.\/[A-Za-z0-9_,-]\{1,\}\.[a-f0-9]\{40\}\.[a-z0-9]\{2,5\}"
}

@test "$base: compile regex for name pattern (II)" {
  check_skipped_envs travis || skip "FIXME broken after main.lib.sh rewrite"
  source ./match.sh load-ext
  source ./match.lib.sh
  silent=true
  match_load
  match_name_pattern ./@NAMEPART.@SHA1_CKS@OPTPART.@EXT
  test $? -eq 0
  test "$grep_pattern" = "\.\/[A-Za-z0-9_,-]\{1,\}\.[a-f0-9]\{40\}\(\.\(partial\|part\|incomplete\)\)\?\.[a-z0-9]\{2,5\}"
}

@test "$base: compile regex for name pattern (III)" {
  check_skipped_envs travis || skip "FIXME seems requires ~/.conf or something"
  source ./match.sh load-ext
  source ./match.lib.sh
  silent=true
  match_load
  match_name_pattern ./@NAMEPART.@SHA1_CKS@PART.@EXT
  test $? -eq 0
  test "$grep_pattern" = "\.\/[A-Za-z0-9_,-]\{1,\}\.[a-f0-9]\{40\}\.\(partial\|part\|incomplete\)\.[a-z0-9]\{2,5\}"
  match_name_pattern ./@NAMEPART.@SHA1_CKS@PART.@EXT PART
  test $? -eq 0
  expected="\.\/[A-Za-z0-9_,-]\{1,\}\.[a-f0-9]\{40\}\(\.\(partial\|part\|incomplete\)\)\.[a-z0-9]\{2,5\}"
  test "$grep_pattern" = "$expected" \
    || fail "Mismatch pattern: '$grep_pattern', but expected '$expected'"
}
