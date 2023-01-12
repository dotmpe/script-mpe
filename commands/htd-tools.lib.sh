#!/bin/sh

htd_man_1__tools='Tools manages simple installation scripts from YAML and is
usable to keep scripts in a semi-portable way, that do not fit anywhere else.

It works from a metadata document that is a single bag of IDs mapped to
objects, whose schema is described in schema/tools.yml. It can be used to keep
multiple records for the same binary, providing alternate installations for
the same tools.

  install [TOOL...]
  uninstall [TOOL...]
  installed [TOOL...]
  validate
  outline
    Transform tools.json into an outline compatible format.
  script

'

htd_tools_help ()
{
  echo "$htd_man_1__tools"
}

htd_tools_list ()
{
  tools_list
}

htd_tools_list_all ()
{
  tools_list_all
}

htd_tools_installed ()
{
  test -n "${1-}" || set -- $(tools_list) ; test -n "$*" || return 2 ;
  test "$out_fmt" = "yml" && echo "tools:" ; while test $# -gt 0
  do
    tools_installed $B/tools.json "$1" && {
      note "Tool '$1' is present"
      test "$out_fmt" != "yml" || printf "  $1:\n    installed: true\n"
    } || {
      test "$out_fmt" != "yml" || printf "  $1:\n    installed: false\n"
    }
    shift
  done
}

htd_tools_install()
{
  while test $# -gt 0
  do
    tools_install $B/tools.json $1 \
      && std_info "Tool $1 is installed" \
      || std_info "Tool $1 install error: $?"
    shift
  done
}

htd_tools_uninstall()
{
  while test $# -gt 0
  do
    tools_uninstall $B/tools.json "$1" \
      && std_info "Tool $1 is not installed" \
      || { r=$?;
        test $r -eq 1 \
          && std_info "Tool $1 uninstalled" \
          || std_info "Tool uninstall $1 error: $r" $r
      }
    shift
  done
}

htd_tools_validate()
{
  tools_json_schema || return 1
  # Note: it seems the patternProperties in schema may or may not be fouling up
  # the results. Going to venture to outline based format first before returning
  # to which JSON schema spec/validator supports what.
  jsonschema -i $B/tools.json $B/tools-schema.json &&
      stderr ok "jsonschema" || stderr warn "jsonschema"
  jsonspec validate --document-file $B/tools.json \
    --schema-file $B/tools-schema.json &&
      stderr ok "jsonspec" || stderr warn "jsonspec"
}

htd_tools_outline()
{
  rm $B/tools.json
  out_fmt=yml htd_tools_installed | jsotk update --pretty -Iyaml $B/tools.json -
  { cat <<EOM
{ "id": "$(prefix_resolve "$(pwd -P)")/tools.yml",
  "hostname": "$hostname", "updated": ""
}
EOM
} | jsotk update -Ijson --pretty $B/tools.json -
  { cat <<EOM
{
  "pretty": true, "doc": $(cat $B/tools.json)
}
EOM
} > $B/tools-outline-pug-options.json
  pug -E xml --out $B/ \
    -O $B/tools-outline-pug-options.json var/tpl/pug/tools-outline.pug
}

htd_tools_generate()
{
  test $# -eq 1 -a -n "${1-}" || return 64
  tools_generate_script $B/tools.json "$1"
}

htd_tools_depends()
{
  test $# -eq 1 -a -n "${1-}" || return 64
  tools_depends $B/tools.json "$1"
}
