#!/bin/sh

# Manage files, folders with perma-URL style archive-paths

cabinet_lib_load()
{
  title= upper=1 default_env HtDir "$HOME/htdocs" &&
  cabinet_init
}

cabinet_init()
{
  test -e cabinet && {
    true "${CABINET_DIR:="$PWD/cabinet"}"
  } || {
    true "${CABINET_DIR:="$HTDIR/cabinet"}"
  }
  # XXX: cleanup default-env
  #  title= upper=1 default_env Cabinet-Dir "$PWD/cabinet"
  #} || {
  #  title= upper=1 default_env Cabinet-Dir "$HTDIR/cabinet"
  #}
}

cabinet_req()
{
  test -d "$CABINET_DIR" || error "Cabinet required <$CABINET_DIR>" 1
}

archive_path_map() # [now= archive_date=] ~ [strfmt]
{
  test -n "$1" || set -- "%Y/%m/%d-"
  local archive_path_prefix=''

  # Calculate ts now, or leave empty to use filemtime's
  test -n "$archive_date" && {
      archive_path_prefix="$(date_fmt "$archive_date" "$1")"
    } || {
      trueish "$now" && archive_path_prefix="$(date_fmt "" "$1")"
    }
  while read archive_path_in
  do
    { test -n "$archive_date" || trueish "$now"
    } || {
      test -e "$archive_path_in" || return
      archive_path_prefix=$(date_fmt "$archive_path_in" "$1")
    }
    echo "$archive_path_in $CABINET_DIR/$archive_path_prefix$archive_path_in"
  done
}

cabinet_permalog() # Entry Doc-Id Doc-Path
{
  # XXX: assumes today symlink is up-to-date
  test ! -e "$1" || {

    # Append new docstat refs only
    grep -q '^.. permalog: .*\<'"$2"'\>.*' "$1" || {
      # Append/insert file as rSt comment to todays entry
      jrnl_line=".. permalog: $2 <$3>"

      grep -q '^\s*\.\. ins.*' "$1" && {
        # TODO: take over indentation of insert: sentinel too
        file_insert_where_after '^\s*\.\.\ ins.*' "$1" "$jrnl_line"
      } || {
        echo "$jrnl_line" >> "$1"
      }
    }
  }
}
