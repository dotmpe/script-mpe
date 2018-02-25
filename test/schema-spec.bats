#!/usr/bin/env bats

load init


@test "package to JSON" {

  jsotk.py yaml2json package.yaml .package.json
}

@test "package schema to JSON" {

  jsotk.py yaml2json schema/package.yml schema/package.json
}

@test "package schema validates" {

  jsonspec validate \
    --document-file .package.json \
    --schema-file schema/package.json \
      || fail $name
}
