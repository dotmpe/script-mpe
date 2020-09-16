#!/bin/sh

# Archive files, list/update contents, unpack and cleanup; frontend routines.

htd_man_1__archive='Deal with archive files (tar, zip)

  test-unpacked ARCHIVE [DIR]
    Given archive, note files out of sync
  clean-unpacked ARCHIVE [DIR]
  note-unpacked ARCHIVE [DIR]
'

htd_archive__help ()
{
  #echo "$htd_man_1__archive"
  std_help archive
}


htd__archive()
{
  test -n "$1" || set -- help
  subcmd_prefs=${base}_archive_ try_subcmd_prefixes "$@"
}
htd_flags__archive=fl
htd_libs__archive=archive\ htd-archive


#htd_env__clean_unpacked='P'


htd_archive_list()
{
  archive_verbose_list "$@"
}


# Given archive, note files out of sync
htd_test_unpacked() # ARCHIVE [DIR]
{
  test -n "$1" || error "archive expected" 1
  test -n "$2" || set -- "$1" "$(dirname "$1")"

  test -e "$1" && {
    test -f "$1" || error "not a file: '$1'" 1
  } || {
    test -h "$1" && {
      warn "skipped broken symlink '$1'"
      return 1
    } || error "No archive '$1'" 2
  }

  local  archive="$(basename "$1")"

  set -- "$(cd "$(dirname "$1")"; pwd -P)/$archive" "$2"

  local oldwd="$PWD" dirty=
  #"$(statusdir.sh file htd test-unpacked)"
  #test ! -e "$dirty" || rm "$dirty"

  cd "$2"

  archive_update "$1" || dirty=1

  cd $oldwd

  test -z "$dirty" && std_info "OK $1" || warn "Crufty $1" 1
}


htd_man_1__clean_unpacked='Given archive, look for unpacked files in the
neighbourhood. Interactively delete, compare, or skip.
'
htd__clean_unpacked() # ARCHIVE [DIR]
{
  test -n "$1" || error "archive" 1
  test -n "$2" || set -- "$1" "$(dirname "$1")"

  test -e "$1" && {
    test -f "$1" || error "not a file: '$1'" 1
  } || {
    test -h "$1" && {
      warn "skipped broken symlink '$1'"
      return 1
    } || error "Not a file or symlink: '$1'" 2
  }
  local  archive="$(basename "$1")" dir="$(dirname "$1")"
  # Resolve symbolic parts:
  set -- "$(cd "$dir"; pwd -P)/$archive" "$2"

  local oldwd="$PWD" \
      cnt=$(setup_tmpf .cnt) \
      cleanup=$(setup_tmpf .cleanup) \
      dirty=$(setup_tmpf .dirty)
  test ! -e "$cleanup" || rm "$cleanup"
  test ! -e "$dirty" || rm "$dirty"
  test -n "$P" || {

    # Default lookup path: current dir, and dir with archive basename name
    P="$2"
    archive_dir="$(archive_basename "$1")"
    test -e "$2/$archive_dir" && P="$P:$2/$archive_dir"
  }

  cd "$2"
  note "Checking for unpacked from '$1'.."
  #trueish "$strict" && {
    # Check all files based on checksum, find any dirty ones
    archive_update "$1" && {
      not_trueish "$dry_run" && {
        test ! -s "$cleanup" || {
          cat $cleanup | while read p
          do rm "$p"; done;
          note "Cleaned $(count_lines $cleanup) unpacked files from $1"
          rm $cleanup
        }
      } || {
        note "All looking clean $1 (** DRY-RUN **) "
      }
    }
  #} || {
  #  echo TODO: go about a bit more quickly archive_cleanup "$1"
  #}

  unset P

  cd "$oldwd"
  test ! -e "$dirty" && stderr ok "$1" || warn "Crufty $1" 1
}


htd_man_1__note_unpacked='Given archive, note unpacked files.

List archive contents, and look for existing files.
'
htd__note_unpacked() # ARCHIVE [DIR]
{
  test -n "$1" || error "note-unpacked 'ARCHIVE'" 1
  test -n "$2" || set -- "$1" "$(dirname "$1")"

  test -e "$1" && {
    test -f "$1" || error "not a file: '$1'" 1
  } || {
    test -h "$1" && {
      warn "skipped broken symlink '$1'"
      return 1
    } || error "No archive '$1'" 2
  }

  local  archive="$(basename "$1")"

  set -- "$(cd "$(dirname "$1")"; pwd -P)/$archive" "$2"

  local oldwd="$PWD" dirty="$(statusdir.sh file htd note-unpacked)"
  test ! -e "$dirty" || rm "$dirty"

  cd "$2"

  archive_list "$1" | while read file
  do
    test -e "$file" && {
      note "Found unpacked $file (from $archive)"
      touch $dirty
      # check for changes?
    } || {
      debug "No file $PWD/$file"
      continue
    }
  done

  cd "$oldwd"

  test ! -e "$dirty" && std_info "OK $1" || warn "Crufty $1" 1
}
