#!/bin/sh


schema_fordoc()
{
  false
}

htd_schema_validate()
{
  test -n "$1" || error "document expected" 1
  test -f "$1" || error "document file expected: '$1'" 1
  test -n "$2" || set -- "$1" "$(schema_fordoc "$1")"
  test -f "$2" || error "schema file expected: '$2'" 1

  local jsonf="$(get_jsonfile "$1")" jsonschemaf="$(get_jsonfile "$2")"

  #jsonspec validate --document-file $jsonf --schema-file $jsonschemaf &&
  #    stderr ok "schema" || error "schema" 1

  ./node_modules/ajv-cli/index.js -s $jsonschemaf -d $jsonf &&
      stderr ok "schema" || error "schema" 1
}
