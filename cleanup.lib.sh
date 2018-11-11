#!/bin/sh


scan_names()
{
  # TODO: see list, compile find query from meta
  test -n "$1" || set -- .

  find "$1" -not -path '*.git*' \( \
    -name '*.JPG' \
 -o -name '*.jpeg' \
 -o -name '*.tiff' \
 -o -name '*.BMP' \
 -o -name '*.JPEG' \
 -o -name '*.GIT' \
 -o -name '*.PNG' \
 -o -name '*.PSD' \
 -o -name '*.TGA' \
 -o -name '*.TIFF' \)

  find "$1" -not -path '*.git*'  \( \
    -iname '._*' \
    -o -iname '.DS_Store' \
    -o -iname 'Thumbs.db' \
    -o -iname '~uTorrentPartFile*' \
  \)

  find "$1" -not -path '*.git*' -type d -empty
}
