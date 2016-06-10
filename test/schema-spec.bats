#!/usr/bin/env bats

load helper


@test "package schema" {

  jsotk.py yaml2json schema/package.yml schema/package.json

  jsotk.py yaml2json package.yaml .package.json

  jsonspec validate \
    --document-file .package.json \
    --schema-file schema/package.json \
      || fail $name
}

