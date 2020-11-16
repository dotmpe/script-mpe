#!/bin/sh


web_lib_load()
{
  # Match Ref-in-Angle-brachets or URL-Ref-Scheme-Path
  url_re='\(<[_a-zA-Z][_a-zA-Z0-9-]\+:[^> ]\+>\|\(\ \|^\)[_a-zA-Z][_a-zA-Z0-9-]\+:\/\/[^ ]\+\)'
  url_bare_re='[_a-zA-Z][_a-zA-Z0-9-]\+:\/[^>\ ]\+'
  test -x "$(which curl)" && bin_http=curl || {
    test -x "$(which wget)" && bin_http=wget || return
  }
}

wanip()
{
  test -x "$(which dig)" && {
    dig +short myip.opendns.com @resolver1.opendns.com || return $?
  } || {
    curl -s http://whatismyip.akamai.com/ || return $?
  }
}

urlencode()
{
  python -c "import urllib; print(urllib.quote_plus(\"$1\"));"
}

urldecode()
{
  python -c "import urllib; print(urllib.unquote_plus(\"$1\"));"
}

htd_urls_encode()
{
  p= s= act=urlencode foreach_do "$@"
}

htd_urls_decode()
{
  p= s= act=urldecode foreach_do "$@"
}

urls_grep () # [SRC|-]
{
  grep -io "$url_re" "$@" | tr -d '<>"''"' # Remove angle brackets or double quotes
}

# Scan for URLs in file. This scans both <>-enclosed and bare URL refs. To
# avoid match on simple <q>:<name> pairs the std regex requires (net)path,
# or use <>-delimiters.
urls_list () # <Path>
{
  test $# -eq 1 || return 98
  urls_grep "$1"
  #| while read -r url
  #do
  #  fnmatch "*:*" "$url" && {
  #    echo "$url"
  #  } || {
  #    #test -n "$fn" || fn="$(basename "$url")"
  #    test -e "$url" || warn "No file '$url'"
  #  }
  #done
}

ext_to_format ()
{
  echo "$1"
}

urls_clean_meta ()
{
  tr -d ' {}()<>"'"'"
}

urls_list_clean ()
{
  test $# -eq 1 || return 98
  local format=$(ext_to_format "$(filenamext "$1")")
  func_exists urls_clean_$format || format=meta
  urls_list "$1" | urls_clean_$format
}

# Download urls
htd_urls_get() # (-|URL)...
{
  htd_urls_get_inner()
  {
    test -n "$fn" || fn="$(basename "$1")"
    test -e "$fn" || {
      wget -q "$1" -O "$fn" && {
        test -e "$fn" && note "New file $fn"
      } || {
        error "Retrieving file $fn"
      }
    }
  }

  p= s= act=htd_urls_get_inner foreach_do "$@"
}

# Scan for URL's, reformat if not enclosed in angles <>. Set second arg to
# rewrite file in place, give extension to make file backup.
htd_urls_todotxt() # File [1|ext]
{
  test -z "$2" && gsed_f= || { test "$2" = "1" && gsed_f=-i || gsed_f=-i$2 ; }
  $gsed $gsed_f 's/\(^\|\ \)\('"$url_bare_re"'\)/\1<\2>/g' "$1"
}

# List URLs in text file, and add to urlstat table. This matches both
# bare-URI references and angle bracked anclosed (<Ref>). See htd-urls-list
htd_urls_urlstat() # Text-File [Init-Tags]
{
  setup_io_paths -$subcmd-${htd_session_id}
  export ${htd__inputs?} ${htd__outputs?}
  opt_args "$@"
  htd_optsv $(lines_to_words $options)
  set -- $(lines_to_words $arguments)

  lib_load urlstat
  urlstat_file="$1" ; shift
  urlstat_check_update=$update
  urlstat_update_process=$process
  htd_urls_list "$urlstat_file" | Init_Tags="$*" urlstat_checkall
  rm "$failed"
}

web_fetch() # URL [Output=-]
{
  test $# -ge 1 -a $# -le 2 || return
  test $# -eq 2 || set -- "$1" -

  case "$bin_http" in
    curl ) curl -sSf "$1" -o $2 ;;
    wget ) wget -q "$1" -O $2 ;;
  esac
}

# Take an REST url and go request
web_resolve_paged_json() # URL Num-Query Page-query
{
  test -n "$1" -a "$2" -a "$3" || return 100
  local tmpd=/tmp/json page= page_size=
  mkdir -p $tmpd
  page_size=$(eval echo \$$2)
  page=$(eval echo \$$3)
  case "$1" in
    *'?'* ) ;;
    * ) set -- "$1?" "$2" "$3" ;;
  esac

  test -n "$page" || page=1
  while true
  do
    note "Requesting '$1$2=$page_size&$3=$page'..."
    out=$tmpd/page-$page.json
    curl -sSf "$1$2=$page_size&$3=$page" > $out
    json_list_has_objects "$out" || { rm "$out" ; break; }
    std_info "Fetched $page <$out>"
    page=$(( $page + 1 ))
  done

  note "Finished downloading"
  test -e "$tmpd/page-1.json" || error "Initial page expected" 1
  count="$( echo $tmpd/page-*.json | count_words )"
  test "$count" = "1" && {
    cat $tmpd/page-1.json
  } || {
    jsotk merge --pretty - $tmpd/page-*.json
  }
  rm -rf $tmpd/
}

json_list_has_objects()
{
  jsotk -sq path $out '0' --is-obj || return
  # XXX: jq -e '.0' $out >>/dev/null || break
}

#
