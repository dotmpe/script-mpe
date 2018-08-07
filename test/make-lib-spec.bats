#!/usr/bin/env bats

load helper

@test "htd make dump" {
  run $BATS_TEST_DESCRIPTION 
  # simply test for one known var
  match=".DEFAULT_GOAL := default"
  test_ok_lines "$match" || stdfail
}

@test "htd make files" {
  run $BATS_TEST_DESCRIPTION 
  # simply test for one known var
  test_ok_lines \
      Makefile rbp-timelapse/Makefile \
      .Rules.rdf.mk .Rules.sa.mk Rules.mk Rules.shared.mk \
          || stdfail
}

@test "htd make expandall" {
  run $BATS_TEST_DESCRIPTION 
  # simply test for one known var
  test_ok_lines ".DEFAULT_GOAL: default" || stdfail
}

@test "htd make targets" {
  run $BATS_TEST_DESCRIPTION 
  # test for some targets; require lines to be present in output
  test_ok_lines \
"TODO.list: ./" \
"all:: build test install" \
"build:: stat libcmdng.html TODO.list build_." \
"build_.:" \
"cdn.yml:" \
"ci-list:" \
"ci-test:" \
"rbp-timelapse:" \
"sa-compare:: sa" \
"sa-create::" \
"sa-latest:: sa" \
"sa-list::" \
"sa-schema::" \
"sa-stat::" \
"sa-t::" \
"sa-touch::" \
"sa-vc:: sa" \
"sa::" \
"schema/%.n3:" \
"schema/dc.n3:" \
"schema/dcam.n3:" \
"schema/foaf.n3:" \
"schema/owl.n3:" \
"schema/rdf.n3:" \
"schema/rdfs.n3:" \
"schema/skos.n3:" || stdfail
}
