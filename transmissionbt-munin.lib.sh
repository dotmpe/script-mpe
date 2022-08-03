#!/usr/bin/env bash
# See also https://trac.transmissionbt.com/browser/trunk/extras/rpc-spec.txt

count ()
{
  wc -l "$@" | awk '{print $1}'
}

tlist ()
{
  local act="${1:-all}"
  test $# -eq 0 || shift
  list_$act "$@" | transmission_fix_item_cols
}

list_validate() # (std) ~ # Check if scraper functions work OK
{
  . "${US_BIN:?}/transmission.lib.sh"
  LOG=stderr_
  while read -r numid pct have eta up down ratio status name
  do
    test "$numid" != ID -a "$numid" != Sum: || continue
    num=${numid//\*/}
    pct=${pct//%/}
    test $pct != n/a || pct=
    ti_v_ff=1 transmission_item_validate
  done
}

list_all ()
{
  tail -n +2 "${1:?}" | head -n -1
}

list_active ()
{
  grep ${grep_f:+-}${grep_f:-} ' \(Uploading\|Downloading\|Up & Down\|Seeding\) ' "$1"
}

list_downloading ()
{
  grep ${grep_f:+-}${grep_f:-} ' \(Downloading\|Up & Down\) ' "$1"
}

list_uploading ()
{
  grep ${grep_f:+-}${grep_f:-} ' \(Uploading\|Up & Down\) ' "$1"
}

list_updown ()
{
  grep ${grep_f:+-}${grep_f:-} ' \(Uploading\|Downloading\|Up & Down\) ' "$1"
}

list_seeding ()
{
  grep ${grep_f:+-}${grep_f:-} ' Seeding ' "$1"
}

list_issues ()
{
  grep ${grep_f:+-}${grep_f:-} '^ * [0-9]*\* ' "$1"
}

# Remove whitespaces from transmission-remote --list columns
transmission_fix_item_cols () # (std) ~ # Remove whitespace from columns
{
  sed '
        s/\([0-9]\) \([kMGT]B\) /\1\2 /
        s/\([0-9]\) \(sec\|min\|hrs\|days\) /\1\2 /
        s/ Up & Down / Up-Down /
    '
}

avg_shareratio ()
{
  awk '
        BEGIN { sum = 0 }
        {
            if ( $7 != "None" ) {
                sum += $7
            }
        }
        END { if ( sum > 0 ) { print sum/NR } else { print 0 } }
    '
}

max_shareratio ()
{
  awk '
        BEGIN { max = 0 }
        {
            if ( $7 != "None" && $7 >= max ) {
                max = $7
            }
        }
        END { print max }
    '
}

assert_helper ()
{
  test -n "${helper_py:-}" || {
    test -e "$MUNIN_LIBDIR/plugins/transmissionbt.py" &&
        helper_py=$MUNIN_LIBDIR/plugins/transmissionbt.py ||
        helper_py=${US_BIN:?}/transmissionbt.py
  }
  test -x "$helper_py" \
    && echo "# Helper $helper_py" \
    || {
        echo "# Missing transmissionbt.py"
        return 1
      }
}

stderr_ ()
{
  echo "$*" >&2
}

#
