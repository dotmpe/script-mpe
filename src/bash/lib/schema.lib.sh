#!/bin/sh

## Validate against JSON schema

schema_lib__load ()
{
  true "${ajv_cli:=${scriptpath:?}/node_modules/ajv-cli/index.js}"
}

schema_lib__init ()
{
  test -x "$ajv_cli" || $LOG error "" "Installation needed" "ajv-cli" 1
  ! sys_debug -dev -debug -init ||
    $LOG notice "" "Initialized schema.lib" "$(sys_debug_tag)"
}

schema_fordoc()
{
  false # TODO
}

htd_schema_validate()
{
  test -n "${1-}" || error "document expected" 1
  test -f "$1" || error "document file expected: '$1'" 1
  #test -n "$2" || set -- "$1" "$(schema_fordoc "$1")"
  test -f "${2-}" || error "schema file expected: '$2'" 1

  local jsonf="$(get_jsonfile "$1")" jsonschemaf="$(get_jsonfile "$2")"

  #jsonspec validate --document-file $jsonf --schema-file $jsonschemaf &&
  #    stderr ok "schema" || { error "schema" ; return 1 ; }

  $ajv_cli -s $jsonschemaf -d $jsonf &&
      stderr ok "schema" || { error "schema" ; return 1 ; }
}
