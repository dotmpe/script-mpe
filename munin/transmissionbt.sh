#!/usr/bin/env bash
# See also https://trac.transmissionbt.com/browser/trunk/extras/rpc-spec.txt

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

transmission_fix_item_cols ()
{
  sed '
        s/\([0-9]\) \([kMGT]B\) /\1\2 /
        s/\([0-9]\) \(min\|hrs\|days\) /\1\2 /
        s/ Up & Down / Up-Down /
    '
}

avg_shareratio ()
{
  awk '
        BEGIN { sum = 0; }
        {
            if ( $7 != "None" ) {
                sum += $7
            }
        }
        END { print sum/NR }
    '
}

max_shareratio ()
{
  awk '
        BEGIN { max = 0; }
        {
            if ( $7 != "None" && $7 >= max ) {
                max = $7
            }
        }
        END { print max; }
    '
}

#
