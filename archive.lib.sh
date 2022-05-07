#!/bin/sh

# Deal with Archive files (packed files, folders' usually compressed):
# list/update contents, unpack and cleanup.


archive_lib_load ()
{
  # 'tar' should be after other compressions
  : "${archive_exts:="rar zip bz2 gz tar tgz 7z"}"
}


# Remove known extension or give error.
archive_basename () # ~
{
  test -n "$1" || error "archive-basename:1" 1
  test -z "$2" || error "surplus arguments '$*'" 1
  local exts=$(printf '.%s ' $archive_exts)
  case "$1" in

    *.rar | *.zip | *.bz2 | *.gz | *.tar | *.tgz | *.7z )
        basename "$1" $exts ;;

    * )
        error "archive-basename ext: '$1'" 1
      ;;
  esac
}

archive_paths () # ~ [DIR] ['find'|'find-first'|'locate'|'locate-first']
{
  case "${2:-"find"}" in
      locate ) archive_paths_locate "${1:-"."}" ; return ;;
      locate-first ) locate_opts="-l 1" archive_paths_locate "${1:-"."}" ; return ;;
      find ) find_args="-a -print" ;;
      find-first ) find_args="-a -print -a -quit" ;;
  esac

  # Locate cannot use ignore filter, but find can.
  ignores_cache || return

  # shellcheck disable=SC2140
  local find_ignores="-false $(ignores_find "$Path_Ignores")"\
" -o -exec test -e \"{}/$IGNORE_DIR\" ';' -a -prune -o -true"

  local archive_names="$(printf -- '-name "*.%s" -o ' $archive_exts) -false"

  eval find ${find_opts:-"-H"} "${1:-.}" \
      \\\( $find_ignores \\\) -a \\\( $archive_names \\\) $find_args
}

# Using locate DB; cannot filter ignores. Ie. should consider ignores on DB
# update.
archive_paths_locate () # ~ [DIR]
{
  set -- "$(realpath "${1:-.}")"
  eval locate ${locate_opts:-""} $(printf -- '"'"$1"'/*.%s" ' $archive_exts)
}

# Look at archive base name, or at root-level packed path name and list existing
# paths we find.
#
archive_paths_unpacked () # ~ [DIR] [ECHO=base|archive|both] [FIND]
{
  # FIXME: need to go breath first for all archive-exts, ie. call archive_paths
  # for first level, add unpacked dirs to Path-Ignores and then recurse for each
  # (unignored) subdir.
  archive_paths ${1:-} ${3:-"find"} | archive_list_unpacked ${2:-}
}

# List filenames in archive
archive_list() # Archive
{
  test -n "$1" || error "archive-list:1" 1
  test -z "${2:-}" || error "surplus arguments '$*'" 1
  case "$1" in

    ( *.iso )
        7z l "$1" | archive_list__read_tab_col Name
        return
      ;;

    ( *.rar )
        unrar l "$1" | archive_list__read_tab_col Name
        return
      ;;

    ( *.tar | *.tar.* | *.tgz )
        tar --list -f "$1"
        return
      ;;

    ( *.zip )
        unzip -l "$1" | archive_list__read_tab_col Name
        return
      ;;

    ( *.7z )
        7za l "$1" | archive_list__read_tab_col Name
        return
      ;;

    ( *.bz2 )
        basename "$1" .bz2
        return
      ;;

    ( *.gz )
        basename "$1" .gz
        return
      ;;

    ( * )
        error "archive-list ext: '$1'" 1
      ;;
  esac
}

# XXX: reads last column, named COLNAME
archive_list__read_tab_col () # ~ [COLNAME]
{
  test $# -gt 0 || set -- Name
  local oldIFS=$IFS line
  IFS=$'\n'

  while read -r line
  do
    case "$line" in *" $1" ) break;; esac
  done

  offset=$(( $(printf "$line" | sed 's/^\(.*\)'"$1"'.*/\1/g' | wc -c) + 1 ))
  # shellcheck disable=SC2162
  read
  while read -r line
  do
    case "$line" in ----* ) break;; esac
    echo "$line"
  done | cut -c$offset-

  IFS=$oldIFS
}

archive_list_basedirs () # ~ ARCHIVE
{
  archive_list "$1" | { grep '[^\.]/' || true; } | cut -d'/' -f1 | remove_dupes
}

# Take list of archive names on stdin and try to see if archive is unpacked at
# current working dir. Lists unpacked files or directories.
archive_list_unpacked () # ~ [ECHO=base|archive|both]
{
  local exts=$(printf '.%s ' $archive_exts)

  while read -r aname
    do

      # XXX: does not look for unpack-to-current dir situations. Just looks at
      # basename, and wether archive has a single root dir-path inside only.
      # Could set option to look for all root-level dirs...
      test "${archive_list_unpacked:-}" = "all" && {

          dirs="$(archive_list_basedirs "$aname")" || return
      } || {
          # Get two lines, check if single line or more. Ignore multiple.
          # XXX: pathname cannot contain spaces
          dirs="$(archive_list_basedirs "$aname" | head -n2)"
          case "$dirs" in *" "*) dir="";; * ) dir="$dirs";; esac
      }

      for basename in "$(pathname "$aname" $exts)" $dir
      do
          test -e "$basename" || continue
          case "${1:-"base"}" in
              ( archive ) echo "$aname" ;;
              ( base ) echo "$basename" ;;
              ( both ) echo "$aname"$'\t'"$basename" ;;
              ( note )
                  $LOG note "" "Found probable unpacked path" "$basename for $aname"
                  echo "$basename" ;;
          esac
      done
    done

}

# TODO: update/list files out of sync
# XXX: best way seems to use CRC (from -lv output at Darwin)
archive_update () # cleanup=<path> dirty=<path> cntf=<path> Archive
{
  test -n "$1" || error "archive-update:1" 1
  test -z "$2" || error "surplus arguments '$*'" 1

  printf 0 >$cntf
  case "$1" in

    *.zip )
        archive_verbose_list $1 length crc32 name | while read -r length crc32 name
        do
          lookup_test="" lookup_path P "$name" | while read -r path
          do
            debug "Unpacked: $name ($crc32, $length)"
            test -f "$name" || continue

            # First check filesize from stat
            test "$(filesize "$name")" = "$length" && {

              # Calculate CRC to verify match
              test "$(crc32 "$name")" = "$crc32" && {

                test $verbosity -gt 5 && stderr ok "Up to date: $name (from $1)"
                printf -- "$name\n" >>$cleanup
              } || {

                warn "CRC-error $name ($1)" 1
                printf -- "$name\n" >>$dirty
              }
            } || {

              warn "Size mismatch $name ($1)" 1
              printf -- "$name\n" >>$dirty
            }
          done
        done
      ;;

    * )
        error "archive-update ext: '$1'" 1
      ;;
  esac
  c=$(cat $cntf); test -s "$dirty" && d=$(count_lines $dirty) || d=
  test -z "$d" &&
      stderr ok "$1 ($c counts)" ||
      warn "Dirty $1 ($d counts, $c total)" 1
}


# Handle archiver list output, echo requested fields
archive_verbose_list() # Archive Fields
{
  test -n "$1" || error "archive-verbose-list:1" 1
  local f=$1
  shift 1
  test -n "$*" || error "archive-verbose-list:fields" 1
  fields="$(for x in "$@"; do printf "\$$x "; done)"
  case "$f" in

    *.zip )
        unzip -lv "$f" | read_unzip_verbose_list | while read -r line
        do
          length="$(echo $line | cut -d\  -f 1)"
          method="$(echo $line | cut -d\  -f 2)"
          size="$(echo $line   | cut -d\  -f 3)"
          ratio="$(echo $line  | cut -d\  -f 4)"
          date="$(echo  $line  | cut -d\  -f 5)"
          time="$(echo  $line  | cut -d\  -f 6)"
          crc32="$(echo  $line | cut -d\  -f 7)"
          name="$(echo   $line | cut -d\  -f 8-)"
          eval echo $fields
        done
      ;;

    * )
        error "archive-list ext: '$1'" 1
      ;;
  esac
}
# Parser for unzip -lv output
read_unzip_verbose_list()
{
  test -n "${cntf:-}" || {
    cntf=$(setup_tmpf .cnt)
    printf 0 >$cntf
  }
  oldIFS=$IFS
  IFS=$'\n'
  # shellcheck disable=SC2162
  read # 'Archive:'
  read -r hds # headers
  read -r cols # separator
  # Lines
  while read -r line
  do
    # shellcheck disable=SC2035
    fnmatch *"----"* "$line" && break
    printf -- "%s\n" "$line"
    # Increment counter
    c=$(cat "$cnt")
    test $c -gt 0 -a $(echo $c' % 1500'|bc) = 0 &&
      note "Large archive: $c files.."
    printf $(( $c + 1 )) > $cntf
  done
  read -r cols # separator
  # shellcheck disable=SC2162
  read # totals
  IFS=$oldIFS
}

#
