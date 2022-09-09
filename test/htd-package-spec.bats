#!/usr/bin/env bats

base=htd
load init

setup()
{
  init 1 0 && load stdtest extra assert
  htd_eval() { v=4 htd_flags__eval=$1 $bin eval "echo \$$2"; }
}

#@test "$base: package: loads local script package.yaml if in ~/bin" {
# See flag 'p', 'q' and 'Q'
#}

@test "$base: main: flag 'p' prepares to update and/or load local project package" {
  run htd_eval p PACKMETA; test_ok_nonempty "package.yaml" || stdfail 1a
  run htd_eval p PACKMETA_SRC; test_ok_empty || stdfail 1b
  run htd_eval p PACK_SH; test_ok_nonempty "./.meta/package/script-2008b-mpe.sh" || stdfail 1c
}

@test "$base: main: flag 'q' prepares to update and tries to load existing local package" {
  run htd_eval q PACKMETA; test_ok_nonempty "package.yaml" || stdfail 2a
  run htd_eval q PACKMETA_SRC; test_ok_empty || stdfail 2b
  run htd_eval q PACK_SH; test_ok_nonempty "./.meta/package/script-2008b-mpe.sh" || stdfail 2c
}

@test "$base: main: flag 'Q' prepares to update, and requires and loads existing local package" {
  run htd_eval Q PACKMETA; test_ok_nonempty "package.yaml" || stdfail 2a
}

