#!/usr/bin/env bats

base=cabinet.lib
load init

setup()
{
  init && lib_load date cabinet && cabinet_init
}


@test "$base: archive-path-map I - now" {

  _r() { foreach "$@" | archive_path_map ; }

  run _r "foo"
  test_nok_empty || stdfail 1.

  run _r "$0"
  { test_ok_nonempty 1 && test_lines "$0 $CABINET_DIR/*-$0" ; } || stdfail 2.
}

@test "$base: archive-path-map II - archive-date=@1514764860" {

  _r() { foreach "$@" | archive_date="@1514764860" archive_path_map ; }

  run _r "foo"
  { test_ok_nonempty 1 && test_lines "* $CABINET_DIR/2018/01/01-foo"
  } || stdfail 1.

  run _r "$0"
  { test_ok_nonempty 1 && test_lines "$0 $CABINET_DIR/2018/01/01-$0"
  } || stdfail 2.
}
