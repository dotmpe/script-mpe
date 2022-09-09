#!/bin/sh


htd_man_1__urls='Grep URLs from plain text.

  urls [encode|decode] ARGS...
    Quote/unquote query, fragment or other URL name parts.
  urls list FILE
    Scan for URLs in text file
  urls get [-|URI-Ref]
    Download
  urls todotxt FILE [1|EXT]
    Output matched URLs enclosed in angled brackets, set 1 to reformat file
    and EXT to backup before rewrite.
  urls urlstat [--update] LIST [Init-Tags]
    Add URLs found in text-file LIST to urlstat index, if not already recorded.
    With update, reprocess existing entries too.

'
htd_flags__urls=fl
htd__urls()
{
  test -n "$1" || set -- list
  subcmd_prefs=${base}__urls__\ ${base}_urls_\ urls_ try_subcmd_prefixes "$@"
}
htd_libs__urls='statusdir urlstat web'


htd_urls_list ()
{
  local cwd=$PWD file=
  htd_urls_args_req "$@" && urls_list $file
}


htd_urls_args_req ()
{
  test -n "${1-}" && file=$1 || file=urls.list
  test -e "$file" || error "urls-list-file '$file'"  1
}

htd_man_1__urlstat='Build urlstat index

  tab [Glob] [URLs.list]
    List entries
  list [Glob] [Stat-Tab]
    List URI-Refs, see htd urls for other URL listing cmds.
  exists URI-Ref [Stat-Tab]
    Test for entry
  grep URI-Ref [Stat-Tab]
    Grep for entry

  check [--update] [--process] URI-Ref [Tags]
    Add missing entries, update only if default stats changed. To update stat
    or other descriptor fields, or (re)process for new field values set option.
  checkall [-|URI-Refs]...
    Run check
  updateall
    See `htd checkall --update`
  processall
    See `htd checkall --process --update`
'
htd__urlstat()
{
  local old_lk=${log_key-} r; export log_key=$CTX_PID:$scriptname:urlstat:${1-}/$$
  # FIXME: eval '', eval set -- $(lines_to_args "$arguments") # Remove options from args
  subcmd_default=list urlstat_check_update=${update-} \
      subcmd_prefs=urlstat_ try_subcmd_prefixes "$@" || r=$?
  export log_key=$old_lk; return ${r-}
}
htd_flags__urlstat=qiAO
#htd_libs__urlstat="stdio statusdir urlstat"


htd__save_url()
{
  annex=/Volumes/Simza/Downloads
  test "$(pwd -P)" = $annex || cd $annex

  test -n "$1" || error 'URL expected' 1
  test -n "$2" || {
    parseuri.py "$1"
    error "TODO: get filename"
  }
  test ! -e "$2" || error "File already exists: $2" 1
  git annex addurl "$1" --file "$2"
}
htd_grp__save_url=annex


htd__urls__status()
{
  ctx_base=ctx__ htd_wf_ctx_sub status @Bookmarks
}


htd__urls__import()
{
  ctx_base=ctx__ htd_wf_ctx_sub import @Bookmarks
}


urls__help ()
{
  echo "urls: $htd_man_1__urls"
  echo "urlstat: $htd_man_1__urlstat"
  #std_help urls
  #std_help urlstat
}



#
