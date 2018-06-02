#!/bin/sh


function wanip()
{
  dig +short myip.opendns.com @resolver1.opendns.com
}

function urlencode()
{
  python -c "import urllib; print(urllib.quote_plus('$1'));"
}
