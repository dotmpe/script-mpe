#!/bin/sh


curl_jsonapi()
{
  test -n "$1" || set -- GET "$2"
  curl -sSf -X "$1" "$2" -H "accept: application/json" -H "Content-Length: 0"
}
