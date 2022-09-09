#!/usr/bin/env bats

base=txt.py
load init

setup()
{
  init &&
  fixture=test/var/urls1
}


@test "txt urllist" {
  run ./$base urllist ${fixture}.list
  test_ok_nonempty 6 || stdfail
}

@test "txt doctree" {
  TODO walk catalogs
  # run ./$base doctree docs.list .
  run ./$base doctree .
  test_ok_nonempty || stdfail
}

@test "txt fold urls" {
  TODO
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
