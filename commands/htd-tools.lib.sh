#!/bin/sh

htd_tools_list()
{
  tools_list
}

htd_tools_installed()
{
  test -n "$1" || set -- $(tools_list) ; test -n "$*" || return 2 ;
  test "$out_fmt" = "yml" && echo "tools:" ; while test -n "$1"
  do
    installed $B/tools.json "$1" && {
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
  local verbosity=6
  while test -n "$1"
  do
    install_bin $B/tools.json $1 \
      && info "Tool $1 is installed" \
      || info "Tool $1 install error: $?"
    shift
  done
}

htd_tools_uninstall()
{
  local verbosity=6
  while test -n "$1"
  do
    uninstall_bin $B/tools.json "$1" \
      && info "Tool $1 is not installed" \
      || { r=$?;
        test $r -eq 1 \
          && info "Tool $1 uninstalled" \
          || info "Tool uninstall $1 error: $r" $r
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
{ "id": "$(htd_prefix "$(pwd -P)")/tools.yml",
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
