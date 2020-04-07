#!/usr/bin/env bash

# Generate index with all date-parts/ranges resolved
journal_entries()
{
  local entry base bn entry title date enddate year monthnr week weeknr daynr
  while read entry path base
  do
    test -z "${DEBUG-}" || echo "journal-entries parsing $base/$path" >&2
    date_journal $(echo $entry | tr '/-' ' ')
    title="$(head -n 1 "$base/$path")"

    # Print Year day-of-year ISO-week date title
    test -n "$yearnr" -o -n "$monthnr" -o -n "$weeknr" && {
      test -n "$yearnr" && {
        # Number for day will be 365 or 366
        # Number for week will be either 52, 53 or 01
        echo "$year $(date --date="$enddate" +'%j') $(date --date="$enddate" +'%V') $entry $title"
      } || {
				echo "$year $daynr-$(date --date="$enddate" +'%j') $week-$(date --date="$enddate" +'%V') $entry $title"
      }
    } || {
      echo "$year $daynr $week $entry $title"
    }
  done | sort
}

#
