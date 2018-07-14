#!/usr/bin/env bats

base=txt.py
load init

setup()
{
  fixture=test/var/urls1
}

@test "txt urllist" {
  run ./$base urllist ${fixture}.list
  test_ok_nonempty || stdfail
}

@test "txt doctree" {
  # run ./$base doctree docs.list .
  run ./$base doctree .
  test_ok_nonempty || stdfail
}

@test "txt fold urls" {
  run ./$base fold ${fixture}.outline ${fixture}.list
  test_ok_empty || stdfail
}

@test "txt unfold urls" {
  run ./$base unfold ${fixture}.list ${fixture}.outline
  test_ok_empty || stdfail
}

@test "txt todolist" {
  run ./$base todolist todo.txt
  test_ok_nonempty || stdfail
}

# FIXME: @test "txt todotxt" {
#  run ./$base todotxt todo.txt
#  test_ok_nonempty || stdfail
#}
