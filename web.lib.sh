#!/bin/sh

wanip()
{
  dig +short myip.opendns.com @resolver1.opendns.com
}

urlencode()
{
  python -c "import urllib; print(urllib.quote_plus('$1'));"
}
