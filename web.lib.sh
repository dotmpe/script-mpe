#!/bin/sh


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
  python -c "import urllib; print(urllib.quote_plus('$1'));"
}

htd_urls_args()
{
  test -n "$1" && file=$1 || file=urls.list
  test -e "$file" || error urls-list-file 1
}

# Read urls for local files from file. If url is local dir, then
# use that to change CWD.
htd__urls_list()
{
  local cwd=$(pwd) file=
  htd_urls_args "$@"
  grep '\([a-z]\+\):\/\/.*' $file | while read -r url fn
  do
    test -d "$cwd/$url" && {
      cd $cwd/$url
      continue
    }
    test -n "$fn" || fn="$(basename "$url")"
    sha1ref=$(printf $url | sha1sum - | cut -d ' ' -f 1)
    md5ref=$(printf $url | md5sum - | cut -d ' ' -f 1)
    #echo $sha1ref $md5ref $url
    test -e "$fn" && {
      note "TODO: check checksum for file $fn"
    } || {
      warn "No file '$fn'"
    }
  done
}

htd__urls_get()
{
  local cwd=$(pwd) file=
  htd_urls_args "$@"
  read_nix_style_file "$file" | while read -r url fn utime size checksum
  do
    test -d "$cwd/$url" && {
      cd $cwd/$url
      continue
    }
    test -n "$fn" || fn="$(basename "$url")"
    test -e "$fn" || {
      wget -q "$url" -O "$fn" && {
        test -e "$fn" && note "New file $fn"
      } || {
        error "Retrieving file $fn"
      }
    }
  done
}
