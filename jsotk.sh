#!/usr/bin/env bash
#
# jsotk.sh
# Copyright (C) 2026 .mpe <dev@dotmpe>
#
# Distributed under terms of the MIT license.

case "$1" in
  ( dotpaths ) jq 'paths | join(".")' "${@:2}" ;;
  ( path-tsv ) jq -r 'paths(select(type!="object" and type!="array")) as $p | [
      ($p|join(".")), (getpath($p)|tostring)
    ] | @tsv' "${@:2}" ;;
  ( paths ) jq 'paths' "${@:2}" ;;
  ( * ) >&2 echo "$1?"
    false
esac
