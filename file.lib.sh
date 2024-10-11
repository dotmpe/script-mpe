#!/bin/sh


file_lib__load ()
{
  lib_require os std date match
}


# File: some wrappers for os.lib.sh etc.


file_name_precaution() {
  echo "$1" | grep -E '^[]\[{}\(\)A-Za-z0-9\.,!@#&%*?:'\''\+\ \/_-]*$' > /dev/null || return 1
}

file_test_name()
{
  match_grep_pattern_test "$1" || return 1
  file_name_precaution "$1" || return 1
  test "$cmd" = "test-name" && {
    echo 'name ok'
  }
  return 0
}

# True if second path(s) is newer (mtime) than SECONDS, or mtime of first path
file_newer_than() # Seconds-or-Path PATHS...
{
  s_or_path=$1 ; shift
  test -e "$1" || error "htd file newer-than file expected '$1'" 1
  test -e "$s_or_path" && {
    seconds="$(( $(date +%s) - $(file_names=false filemtime "$s_or_path") ))"
  } || {
    # Evaluate delta as $_<name> var if it is not a literal integer
    printf -- "%s" "$s_or_path" | grep -vq '^[0-9]$' &&
        seconds="$(eval echo \"\$_$s_or_path\")" || seconds="$s_or_path"
  }

  file_newer_than_inner()
  {
    ! "${DEBUG:-false}" ||
      debug "newer_than '$1' '$seconds'"
    newer_than "$1" "$seconds" || {
      warn "Failed at '$1' not newer than '$s_or_path'" ; return $?
    }
  }

  p='' s='' act=file_newer_than_inner foreach_do "$@"
}

# True if second path(s) is older (mtime) than SECONDS, or mtime of first path
file_older_than() # Seconds-or-Path PATHS...
{
  local s_or_path="$1" ; shift
  test -e "$1" || error "htd file older-than file expected '$1'" 1
  test -e "$s_or_path" && {
    seconds="$(( $(date +%s) - $(file_names=false filemtime "$s_or_path") ))"
  } || {
    # Evaluate delta as $_<name> var if it is not a literal integer
    printf -- "%s" "$s_or_path" | grep -vq '^[0-9]$' &&
        seconds="$(eval echo \"\$_$s_or_path\")" || seconds="$s_or_path"
  }

  file_older_than_inner()
  {
    test -z "$DEBUG" || debug "older_than '$1' '$seconds'"
    older_than "$1" "$seconds" || {
      warn "Failed at '$1' not older than '$s_or_path'" ; return $?
    }
  }

  p='' s='' act=file_older_than_inner foreach_do "$@"
}

file_newest()
{
  test -n "$1" || set -- . "$2"
  test -n "$2" || set -- "$1" 10
  find $1 -type f -exec stat --format '%Y :%y %n' "{}" \; |
      sort -nr |
      cut -d: -f2- |
      head -n $2
}

file_largest()
{
  test -n "$1" || set -- . "$2"
  test -n "$2" || set -- "$1" 10
  find $1 -type f -exec stat --format '%s %n' "{}" \; |
      sort -nr |
      cut -d' ' -f2- |
      head -n $2
}

# file_names=<bool> file_deref=<bool> htd file format FILE...
file_format()
{
  p='' s='' act=fileformat foreach_do "$@"
}

# file_names=<bool> file_deref=<bool> htd file mediatype FILE...
file_mtype()
{
  p='' s='' act=filemtype foreach_do "$@"
}

# file_names=<bool> file_deref=<bool> htd file mtime FILE...
file_mtime()
{
  p='' s='' act=filemtime foreach_do "$@"
}

file_mtime_relative()
{
  test -n "$datefmt_suffix" || datefmt_suffix='\n'
  # XXX: allow file_names=true, or prefix-filename or something with foreach_do?
  file_names=false
  p='' s='' act=filemtime foreach_do "$@" |
  p='' s='' act=fmtdate_relative foreach_do -
}

# file_names=<bool> file_deref=<bool> htd file btime FILE...
file_btime()
{
  p='' s='' act=filebtime foreach_do "$@"
}

file_btime_relative()
{
  test -n "$datefmt_suffix" || datefmt_suffix='\n'
  p='' s='' act=filebtime foreach_do "$@" |
  p='' s='' act=fmtdate_relative foreach_do -
}

# file_names=<bool> file_deref=<bool> htd file size FILE...
file_size()
{
  p='' s='' act=filesize foreach_do "$@"
}


file_dirnames()
{
  p='' s='' act=dirname foreach_do "$@"
}


# Sort filesizes into histogram, print percentage of bins filled
# Bin edges are fixed
file_size_histogram()
{
  test -n "$1" || set -- "/"
  log "Getting filesizes in '$*'"
  sudo find $1 -type f 2>/dev/null | ./filesize-frequency.py
  return $?
}

file_find()
{
  foreach_item "$@" | catalog_sha2list /dev/fd/1 | file_find_by_sha2list
}

file_find_by_sha2list() # SHA2LIST...
{
  cat "$@" | annices_findbysha2list
}

file_find_by_sha256e()
{
  foreach_item "$@" | while read -r KEY
  do
    annices_content_lookupbykey "$KEY" || return
  done
}

# Read filenames at args or stdin, and drop file. See htd help file,
# and also annex-dropbyname for Annex backend links,
file_drop()
{
  annex="$( go_to_dir_with .git/annex && pwd )" || return 61
  git="$( go_to_dir_with .git && pwd )" || return 62
  # XXX base="$( go_to_dir_with .cllct && pwd )" || return 63

  foreach_item "$@" | while read -r fn
  do
    {
      test -n "$annex" &&
        test -h "$fn" &&
          fnmatch "SHA256E-*"  "$(basename "$(readlink "$fn")")"
    } && {
      annex_dropbyname "$fn" || return
      git rm "$fn" || true
      continue
    } || true
    # XXX: dropbyname records dropped too, but should really handle at catalog
    # level/update catalog.yaml
    #echo "$fn" | catalog_sha2list .catalog/dropped.sha2list
    test -n "$git" && {
      git rm "$fn" || true
    } || {
      rm "$fn" || return
    }
  done
  return
}

file_status()
{
  # Search for by name
  echo TODO track htd__find "$localpath"

  # Search for by other lookup
  echo TODO track htd__content "$localpath"
}

file_extensions()
{
  filenamext "$@"
}

file_stripext()
{
  filestripext "$1"
}
