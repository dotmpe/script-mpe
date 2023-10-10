#!/bin/sh


web_lib__load ()
{
  #lib_require str:fnmatch

  # Match Ref-in-Angle-brachets or URL-Ref-Scheme-Path
  url_re='\(<[_a-zA-Z][_a-zA-Z0-9-]\+:[^> ]\+>\|\(\ \|^\)[_a-zA-Z][_a-zA-Z0-9-]\+:\/\/[^ ]\+\)'
  url_bare_re='[_a-zA-Z][_a-zA-Z0-9-]\+:\/[^>\ ]\+'
  test -x "$(which curl)" && bin_http=curl || {
    test -x "$(which wget)" && bin_http=wget || return
  }
}


web_instances ()
{
  # XXX: track clients, see bittorrent/transmission
  std_pass "$(pidof -s $bin_http)" || return
  echo "web default $_ $bin_http"
}


ext_to_format () # XXX
{
  echo "$1"
}

htd_urls_encode()
{
  p= s= act=urlencode foreach_do "$@"
}

htd_urls_decode()
{
  p= s= act=urldecode foreach_do "$@"
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
  export ${htd_inputs?} ${htd_outputs?}
  opt_args "$@"
  htd_optsv $(lines_to_words $options)
  set -- $(lines_to_words $arguments)

  lib_load urlstat || return
  urlstat_file="$1" ; shift
  urlstat_check_update=$update
  urlstat_update_process=$process
  htd_urls_list "$urlstat_file" | Init_Tags="$*" urlstat_checkall
  rm "$failed"
}

http_deref () # ~ <URL> [<Last-Modified>] [<ETag>] [<Curl-argv>]
{
  test -z "${2:-}" || {
    test -z "${3:-}" || {
      ! fnmatch "*/*" "$2" &&
      ! fnmatch "*/*" "$3" || {
        http_deref_cache_etagfile "$2" "$3" "$1" "${@:4}"
        return
      }
    }
    ! fnmatch "*/*" "$2" &&
    set -- "${@:1:3}" -H "If-Modified-Since: $2" "${@:4}" || {
      http_deref_cache "$2" "$1" "${@:4}"
      return
    }
  }
  test -z "${3:-}" || set -- "${@:1:3}" -H "If-None-Match: ${3:?}" "${@:4}"
  stderr echo curl ${curl_f:--sfL} "${1:?}" "${@:4}"
  curl ${curl_f:--sfL} "${1:?}" "${@:4}"
}

http_deref_cache_etagfile () # ~ <Cache-file> <Etag-file> <URL-ref> [<Curl-argv>]
{
  test -e "${2:?}" && set -- "$@" --etag-compare "${2:?}"
  http_deref_cache "${1:?}" "${@:3}" --etag-save "${2:?}"
}

http_deref_cache () # ~ <Cache-file> <URL-ref> [<Curl-argv...>]
{
  test -e "${1:?}" && set -- "$@" -z "${1:?}"
  http_deref "${2:?}" "" "" "${@:3}" -o "${1:?}"
}

urls_clean_meta ()
{
  tr -d ' {}()<>"'"'"
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

urls_list_clean ()
{
  test $# -eq 1 || return 98
  local format=$(ext_to_format "$(filenamext "$1")")
  func_exists urls_clean_$format || format=meta
  urls_list "$1" | urls_clean_$format
}

wanip()
{
  test -x "$(which dig)" && {
    dig +short myip.opendns.com @resolver1.opendns.com || return $?
  } || {
    curl -s http://whatismyip.akamai.com/ || return $?
  }
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

urldecode () # ~ <String>
{
  : "${1:?}"
  # URL encoded spaces
  : "${_//+/ }"
  # Replace other URL encoded chars with something echo -e/printf understands
  printf '%s\n' "${_//%/\\x}"
}

urldecode_py () # ~ <String>
{
  python -c "import urllib; print(urllib.unquote_plus(\"$1\"));"
}

urlencode () # ~ <String>
{
  ${ue_plus:-true} && set -- "${1// /+}"

  local old_lc_collate=$LC_COLLATE
  LC_COLLATE=C

  local length="${#1}"
  for (( i = 0; i < length; i++ )); do
    local c="${1:$i:1}"
    case $c in
      ( [a-zA-Z0-9.~_+-] ) printf '%s' "$c" ;;
      ( * ) printf '%%%02X' "'$c" ;;
    esac
  done

  LC_COLLATE=$old_lc_collate
}

urlencode_py () # ~ <String>
{
  python -c "import urllib; print(urllib.quote_plus(\"$1\"));"
}

web_html2text ()
{
  set -- -dump 1 \
	 -dump-width ${html_width:-79} \
	 -dump-charset ${html_charset:-ascii} "$@"
  ! ${html_refs:-true} || set -- -no-references "$@"
  ! ${html_refnums:-true} || set -- -no-numbering "$@"
  elinks "$@"
}

#
