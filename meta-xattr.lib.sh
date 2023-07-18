
meta_xattr_lib__load ()
{
  true
}


meta_dump__xattr ()
{
  local data=$(meta_xattr__raw "$@")
  case "${out_fmt:-kv}" in
    ( fields )
        echo "$data"
      ;;
    ( tsv|pairs )
        echo "$data" | sed 's/: /\t/'
      ;;
    ( kv|kqv )
        echo "$data" | sed 's/: /=/' | kv_quote
      ;;
    ( pkv|shkv )
        echo "$data" | conv_fields_shell
      ;;

    ( * ) return 4 ;;
  esac
}

meta_xattr__raw ()
{
  xattr -l "${1:?}"
}

#
