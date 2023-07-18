# Native IO format is JSON, and contains descriptor dates (*lastchanged) and
# command response metadata in structure.
meta_dump__git_annex ()
{
  local data
  case "${out_fmt:-kv}" in

    ( json* )
        data=$(git annex metadata <<< "$(printf '{"file":"%s"}' "${1:?}")")
      ;;

    ( kv* )
        data=$(git annex metadata "${1:?}")
      ;;

    ( * ) return 4 ;;
  esac

  case "${out_fmt:-kv}" in
    ( *-raw ) echo "$data"; return ;;
    ( json-fields ) jq .fields <<< "$data"; return ;;
    ( kv|kqv ) <<< "$data" tail -n +2 | head -n -1 | kv_quote "=" ;;
    ( * ) return 4 ;;
  esac
}

#
