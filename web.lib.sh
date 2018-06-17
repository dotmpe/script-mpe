#!/bin/sh


wanip()
{
  test -x "$(which dig)" && {
    dig +short myip.opendns.com @resolver1.opendns.com || return $?
  } || {
    curl http://canhazip.com || return $?
  }
}

urlencode()
{
  python -c "import urllib; print(urllib.quote_plus('$1'));"
}
