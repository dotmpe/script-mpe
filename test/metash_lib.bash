#!/usr/bin/env bashunit.mpe

function test_metash_lib ()
{
  lib_require metash

  foo_bar_var=yes

  metash_mkgrp foo-bar -- \
    var - -- var2 n -- var3 nx BY_REF -- var4 x default4 -- \
    var5 - def5

  metash_append=true
  metash_prefix=true
  metash_mkgrp foo-bar -- \
    var - -- var2 n -- var3 nx BY_REF -- var4 x default4 -- \
    var5 - def5

  metash_parts
  metash_parttypes
  metash_partfields
  metash_defs

  metash_mkprt my-map-sym A
  my_map_sym=(
    [foo]=bar
    [el]=baz
  )
  metash_dumpvalue -A my_map_sym
}
