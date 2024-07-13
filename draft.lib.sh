htd_draft_create() # Title...
{
  test -z "${htd_draft:-unset}" || local htd_draft_id= htd_draft=

  htd_draft_id_from_title "$@"

  {
    # TODO: check with SD:index/context.list,
    # but would need to write to ~/htdocs/.meta/stat/index/context.list
    echo "$*" > $htd_draft
  }
}

htd_draft_req() # Title...
{
  htd_draft_init && test -e "$htd_draft"
}

htd_draft_init() # Title...
{
  htd_draft_id_from_title "$@" &&
  htd_draft=$HOME/htdocs/draft/$htd_draft_id.rst
}

htd_draft_id_from_title() # Title...
{
  test -n "$*" || {
    set -- $(basename $PWD)
  }
  htd_draft_id=$(str_word "$*")
}

htd_draft_open ()
{
  htd_draft_init "$@"
  test -e $htd_draft || htd_draft_create "$@"
  export ENV_CTX="$ENV_CTX $htd_draft_id"
}

#
