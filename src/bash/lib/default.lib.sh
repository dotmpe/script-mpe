#!/bin/sh

default_lib__load()
{
  test -x "foo" || echo bar
  true
}

default_init()
{
  test -x "foo" || printf bar
}

default_test()
{
  grep -V
  ggrep -V
  false
}
