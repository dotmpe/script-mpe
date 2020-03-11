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

urls__help ()
{
  echo "$htd_man_1__urls"
}
