#!/bin/sh

### Graphical man page?

# There should be another way to do this, but the pipeline
# with man -X fails. Works fine though, but be something in man.

# Except xditview is very poor.
# Better alternatives are xdvi and gv viewer.
# And ofcourse any modern desktop PDF viewer.

# But I'm a bit fuzzy in what the manpage 'publisher pipeline' can do.
# E.g. have not seen hyperlinks in any of these yet.
# No colors as well.

# Btw. on Gnome, yelp is maybe one of the better alternatives but I could
# did find out much about it yet.


# Same as man -X, playing with some other options to xditview
man_xditview ()
{
  zcat $(man -w "$1") | (
    cd /usr/share/man && /usr/lib/man-db/zsoelim
  ) | (
    cd /usr/share/man && /usr/lib/man-db/manconv -f UTF-8:ISO-8859-1 -t UTF-8//IGNORE
  ) | (
    cd /usr/share/man && preconv -e UTF-8
  ) | (
    cd /usr/share/man && tbl
  ) | (
    cd /usr/share/man && groff -f T -mandoc -TX100-12 \
        -P -bw -P 4 \
        -P -bd -P black \
        -P -rv \
        -P -fn -P '-*-*-*-r-narrow-*-*-*-*-*-*-2' \
        -X
  )
}

man_xdvi ()
{
  set -- "$(basename "$(man -w "$@")" .gz)"
  test -s /tmp/$1.dvi || man -Tdvi "$@" > /tmp/$1.dvi
  xdvi \
      -font '-*-*-*-r-narrow-*-*-*-*-*-*-2' \
      -bg '#EEEEEC' \
      -fg '#2E3436' \
      -hl '#78492a' \
      -linkcolor '#0000ff' \
      -s 6 \
      -p 735 \
      -expertmode 0 \
      -gsalpha \
      -rv \
        /tmp/$1.dvi
}

man_gvps ()
{
  set -- "$(basename "$(man -w "$@")" .gz)"
  test -s /tmp/$1.ps || man -Tps "$@" > /tmp/$1.ps
  gv \
      -widgetless \
      -scale=1 \
      -center \
      /tmp/$1.ps
}

#
