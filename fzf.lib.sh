
# FIXME: seems like regexes are not passed/quoted correctly from fzf

#: "${FZF_DEFAULT_COMMAND:=}"
# FZF_CTRL_T_COMMAND
# FZF_CTRL_T_OPTS

fzf_start ()
{
  fnmatch "* --color=*" "$FZF_DEFAULT_OPTS" || {
    FZF_DEFAULT_OPTS="$FZF_DEFAULT_OPTS $FZF_CHAUVET"
  }

  # Defined by Fzf
  test -n "${FZF_DEFAULT_OPTS:-}" || declare -gx FZF_DEFAULT_OPTS
  test -n "${FZF_DEFAULT_COMMAND:-}" || declare -gx FZF_DEFAULT_COMMAND
  # Defined by this lib
  test -n "${FZF_EDIT_OPTS:-}" || declare -gx FZF_EDIT_OPTS

}


# Quick file-select and edit for given (Fzf and Vim) query string(s), using
#
# Start search using query and edit single match, or run Fzf prompt to manually
# select file(s) to edit. If second argument is given, a Vim forward-search
# command option is passed upon invoking $EDITOR.
#
# See: FZF_EDIT_OPTS
fzf_edit_preview () # ~ <Fzf-query-> <Vim-search-re->
{
  local fzf_q="${1:-}" fzf_a vim_q="${2:-}" vim_a

  # Customize UI (see also FZF_DEFAULT_OPTS for user options)
  set -- --header "Choose file(s) to edit" --prompt='> ' \

  # If query is already provided, let Fzf skip query-edit
  # if result is 1-item set.
  test -z "$fzf_q" \
    && set -- "$@" ${FZF_EDIT_OPTS:-} \
    || set -- "$@" ${FZF_EDIT_OPTS:-} --select-1 --query "$fzf_q"

  # Get filename(s) from FZF or return
  #shellcheck disable=2046
  set -- $(fzf-preview $fzf_a "$@") &&
    test $# -gt 0 || return

  # Query within first document using Vim query
  test -z "$vim_q" || set -- -c "/$vim_q" "$@"

  ${fork:-true} && exec $EDITOR $vim_a "$@" || command $EDITOR $vim_a "$@"
}

# Same as fzf-edit-preview, but provide dirs to search as well.
fzf_edit_preview_dirs () # ~ <fzf-edit-preview-argv:2> <Search-dirs...>
{
  initial_cmd=$(printf \
      'rg --column --line-number --no-heading --color=always --smart-case -- %s || true' \
      "${1@Q}")
  reload_cmd='vim_rg {q}'
  exec $initial_cmd
}

vim_rg ()
{
  local query=${1:?}
  rg --column --line-number --no-heading --color=always --smart-case -- $query
}



#
