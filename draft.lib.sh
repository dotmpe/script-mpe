ht_draft_create() # Title...
{
  test -z "${ht_draft:-unset}" || local ht_draft_id= ht_draft=

  ht_draft_id_from_title "$@"

  {
    # TODO: check with SD:index/context.list,
    # but would need to write to ~/htdocs/.meta/stat/index/context.list
    echo "$*" > $ht_draft
  }
}

ht_draft_req() # Title...
{
  ht_draft_init && test -e "$ht_draft"
}

ht_draft_init() # Title...
{
  ht_draft_id_from_title "$@" &&
  ht_draft=$HOME/htdocs/draft/$ht_draft_id.rst
}

ht_draft_id_from_title() # Title...
{
  test -n "$*" || {
    set -- $(basename $PWD)
  }
  ht_draft_id=$(mkvid "$*" ; echo $vid)
}

ht_draft_open ()
{
  ht_draft_init "$@"
  test -e $ht_draft || ht_draft_create "$@"
  export ENV_CTX="$ENV_CTX $ht_draft_id"
}

#
