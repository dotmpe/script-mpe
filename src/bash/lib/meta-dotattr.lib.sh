meta_dotattr_lib__load ()
{
  : "${META_LOCALATTR:=.attributes}"
}


meta__dotattr__dump ()
{
  local data
  data=$(meta__dotattr__raw "$@") &&
  case "${out_fmt:-kv}" in
  ( kv|kqv )
      TODO "@meta/dotattr.dump"
    ;;
  ( * ) return ${_E_nsk:?}
  esac
}

meta__dotattr__exists () # ~ <File>
{
  TODO "@meta/dotattr.exists"
}

meta__dotattr__fetch () # ~ <File>
{
  TODO "@meta/dotattr.fetch"
}

meta__dotattr__new () # ~ <File>
{
  TODO "@meta/dotattr.new"
}

meta__dotattr__raw () # ~ <File>
{
  TODO "@meta/dotattr.raw"
}
