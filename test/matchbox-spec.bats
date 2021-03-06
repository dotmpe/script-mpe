#!/usr/bin/env bats

base=matchbox.py
load init
init


@test "$bin no arguments defaults to 'show' command" {
  test true = "$SHIPPABLE" && skip
  run ${bin}
  test $status -eq 0
  fnmatch "*matchbox.py*" "${lines[*]}"
  fnmatch "*Var-table:*" "${lines[*]}"
  fnmatch "*Templates:*" "${lines[*]}"
  fnmatch "*Paths:*" "${lines[*]}"
}

@test "$bin invalid command gives error" {
  test true = "$SHIPPABLE" && skip
  run ${bin} invalid-command
  test $status -ne 0
}

@test "$bin help: lists command usage docs, with argument signatures" {
  test true = "$SHIPPABLE" && skip
  run ${bin} help
  test $status -eq 0
  fnmatch "* show *" "${lines[*]}"
  fnmatch "* dump *" "${lines[*]}"
  fnmatch "* name-regex NAME_TEMPLATE *" "${lines[*]}"
  fnmatch "* match-name-vars NAME NAME_TEMPLATE_OR_TAG=*" "${lines[*]}"
  fnmatch "* match-names-vars NAME_TEMPLATE_OR_TAG=*" "${lines[*]}"
  fnmatch "* rename FROM_TEMPLATE TO_TEMPLATE EXISTS=*" "${lines[*]}"
  fnmatch "* check-name LINE TAGS... *" "${lines[*]}"
  fnmatch "* check-names TAGS... *" "${lines[*]}"
}
