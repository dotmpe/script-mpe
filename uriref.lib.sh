#!/bin/sh


uriref_lib_load()
{
  # Some character groups in basic RE with RFC 2396 BNF symbol refs
  rfc_ur_mark_r="\-_\.!~*'()"
  # RFC 2396 2.3.
  rfc_ur_unreserved_r="${rfc_ur_mark_r}[:alnum:]"
  rfc_ur_escaped_r="%[:alnum:]"
  # pchar's/params and ; are what makes up path segements in URL,s
  rfc_ur_pchar_r="${rfc_ur_unreserved_re}${rfc_ur_escaped_re}:@&=+$,"
  rfc_ur_param_re="[${rfc_ur_pchar_re}]*"
  # RFC 2396 2.2.
  rfc_ur_reserved_r=";/?:@&=+$,"
  # RFC 2396 2.
  rfc_uric_re="[${rfc_ur_unreserved_re}${rfc_ur_reserved_re}${rfc_ur_escaped_re}]"
  # Query, fragment or opaque part are all uric
  rfc_ur_id_re="${rfc_uric_re}*"

  # URIc is the least restrictive pattern, matching any URI piece and query,
  # fragment or opaque part. URIRef paths are much more restrictive than
  # regular filepaths. Only an explicit range of characters is allowed, that
  # make it possible to extract URIRefs from surrounding text. Anything else
  # beside \-_\.!~*'();/ has to be %-encoded. See rfc-reserved-re.

  # RFC 2396 3.1. Scheme has -+. and no _
  rfc_scheme_re="[[:alpha:]][\-+\.[:alphanum:]]*"

  # Match Ref-in-Angle-brachets or URL-Ref-Scheme-Path
  uri_re='\(urn:[^ ]\+\|<[_a-zA-Z][_a-zA-Z0-9-]\+:[^> ]\+>\|\(\ \|^\)[_a-zA-Z][_a-zA-Z0-9-]\+:\/\/[^ ]\+\)'
}

uriref_grep () # [SRC|-]
{
  grep -o "$uri_re" "$@" | tr -d '<>"''"' # Remove angle brackets or quotes
}

uriref_list () # <Path>
{
  test $# -eq 1 || return 98
  uriref_grep "$1"
}

uriref_clean_meta ()
{
  tr -d ' {}()<>"'"'"
}

uriref_list_clean ()
{
  test $# -eq 1 || return 98
  local format=$(ext_to_format "$(filenamext "$1")")
  func_exists uriref_clean_$format || format=meta
  uriref_list "$1" | uriref_clean_$format
}

#
