# Native IO format is JSON, and contains descriptor dates (*lastchanged) and
# command response metadata in structure.
meta__git_annex__dump () # (out-fmt) ~ <File>
{
  : about "Dump Git Annex metadata for file in requested format"

  local data
  case "${out_fmt:-kv}" in
  ( json* ) meta__git_annex__raw_json data "${1:?}" ;;
  ( kv* ) meta__git_annex__raw data "${1:?}" ;;
  ( * ) return ${_E_nsk:?}
  esac

  case "${out_fmt:-kv}" in
  ( *-raw ) echo "$data"; return ;;
  ( json-fields ) jq .fields <<< "$data"; return ;;
  ( kv|kqv ) <<< "$data" tail -n +2 | head -n -1 | kv_quote "=" ;;
  ( * ) return ${_E_nsk:?}
  esac
}

meta__git_annex__raw () # ~ <Var> <File>
{
  : about "Read Git Annex metadata listing to variable"
  if_ok "$(git annex metadata "${2:?}")" &&
  read -r ${1:?} <<< "$_"
}

meta__git_annex__raw_json () # ~ <Var> <File>
{
  : about "Read Git Annex metadata JSON string to variable"
  if_ok "$(git annex metadata <<< "$(printf '{"file":"%s"}' "${2:?}")")" &&
  read -r ${1:?} <<< "$_"
}

#
