#!/bin/sh

# Archive files, list/update contents, unpack and cleanup


# TODO: update/list files out of sync
# XXX: best way seems to use CRC (from -lv output at Darwin)
archive_update() # cleanup=<path> dirty=<path> cnt=<path> Archive
{
  test -n "$1" || error "archive-update:1" 1
  test -z "$2" || error "surplus arguments '$*'" 1

  printf 0 >$cnt
  case "$1" in

    *.zip )
        archive_verbose_list $1 length crc32 name | while read length crc32 name
        do
          lookup_test= lookup_path P "$name" | while read path
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
  c=$(cat $cnt); test -s "$dirty" && d=$(count_lines $dirty) || d=
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
        unzip -lv "$f" | read_unzip_verbose_list | while read line
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
  test -n "$cnt" || cnt=$(setup_tmpf .cnt)
  oldIFS=$IFS
  IFS=\n
  read # 'Archive:'
  read hds # headers
  read cols # separator
  # Lines
  while read line
  do
    fnmatch *----* "$line" && break
    printf -- "%s\n" "$line"
    # Increment counter
    c=$(cat "$cnt")
    test $c -gt 0 -a $(echo $c' % 1500'|bc) = 0 &&
      note "Large archive: $c files.."
    printf $(( $c + 1 )) > $cnt
  done
  read cols # separator
  read # totals
  IFS=$oldIFS
}

# Same handler+parser for normal unzip -l, give just name (from Length, Date, Time, Name)
archive_list() # Archive
{
  test -n "$1" || error "archive-list:1" 1
  test -z "$2" || error "surplus arguments '$*'" 1
  case "$1" in

    *.zip )
        unzip -l "$1" | read_unzip_list
      ;;

    * )
        error "archive-list ext: '$1'" 1
      ;;
  esac
}
read_unzip_list()
{
  test -n "$cnt" || cnt=$(setup_tmpf .cnt)
  oldIFS=$IFS
  IFS=\n
  read
  read headers
  # see fixed_table_hd_offset; dont bother with 0-index correction here
  # XXX: expr still helps to strip ws even with IFS off..? [Darwin]
  offset=$(( $(printf "$headers" | sed 's/^\(.*\)'Name'.*/\1/g' | wc -c) - 0 ))
  read
  while read line
  do
    case $line in " "*---- | " "*[0-9]*" files" ) continue ;; esac
    printf -- "%s" "$line" | cut -c$offset-
    # Increment counter
    printf $(( $(cat "$cnt") + 1 )) > $cnt
  done
  IFS=$oldIFS
}


archive_basename()
{
  test -n "$1" || error "archive-basename:1" 1
  test -z "$2" || error "surplus arguments '$*'" 1
  case "$1" in

    *.zip )
        basename "$1" .zip
      ;;

    * )
        error "archive-basename ext: '$1'" 1
      ;;
  esac
}
