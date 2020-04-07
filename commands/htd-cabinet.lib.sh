#!/bin/sh


htd_man_1__cabinet='Manage files, folders with perma-URL style archive-paths

  cabinet add [--{not-,}-dry-run] [--archive-date=] REFS..
    Move path to Cabinet-Dir, preserving timestamps and attributes. Use filemtime
    for file unless now=1.

        <refs>...  =>  <Cabinet-Dir>/%Y/%m/%d-<ref>...

Env
    CABINET_DIR $PWD/cabinet $HTDIR/cabinet
'
htd_cabinet__help ()
{
  echo "$htd_man_1__cabinet"
}


htd_cabinet_lib_load()
{
  default_env Cabinet-Dir "cabinet" || debug "Using Cabinet-Dir '$CABINET_DIR'"
  default_env Jrnl-Dir "personal/journal" || debug "Using Jrnl-Dir '$JRNL_DIR'"
  # set -u
  shopt -s extglob
  shopt -s globstar
}


htd_cabinet_add() # Refs
{
  test -n "${1-}" || warn "expected references to backup" 1
  { test -n "$1" && { foreach "$@" || return ; } || cat ; } | sed 's/\/$//' |
  # Add trailing '/' for first and remove for second, for rsync to handle dir
    while read p ; do test -d "$p" && echo "$p/" || echo "$p" ; done |
    archive_path_map | sed 's/\/$//' | rsync_pairs
}

htd_libs__cabinet="str-htd"


htd_man_1__archive_path='
# TODO consolidate with today, split into days/week/ or something
'
htd_spec__archive_path='archive-path DIR PATHS..'
htd__archive_path()
{
  test -n "$1" || set -- cabinet/
  test -d "$1" || {
    fnmatch "*/" "$1" && {
      error "Dir $1 must exist" 1
    } || {
      test -d "$(dirname "$1")" ||
        error "Dir for base $1 must exist" 1
    }
  }
  fnmatch "*/" "$1" || set -- "$1/"

  Y=/%Y M=-%m D=-%d archive_path "$1"

  datelink -1d "$archive_path" ${ARCHIVE_DIR}yesterday$EXT
  echo yesterday $datep
  datelink "" "$archive_path" ${ARCHIVE_DIR}today$EXT
  echo today $datep
  datelink +1d "$archive_path" ${ARCHIVE_DIR}tomorrow$EXT
  echo tomorrow $datep

  unset archive_path archive_path_fmt datep target_path
}
# declare locals for unset
htd_vars__archive_path="Y M D EXT ARCHIVE_BASE ARCHIVE_ITEM datep target_path"



htd_man_1__edit_today='Edit todays log: an entry in journal file or folder.

If argument is a file, a rSt-formatted date entry is added. For directories
a new entry file is generated, and symbolic links are updated.

TODO: accept multiple arguments, and global IDs for certain log dirs/files
TODO: maintain symbolic dates in files, absolute and relative (Yesterday, Saturday, 2015-12-11 )
TODO: revise to:

- Uses pd-meta.log setting from package, or JRNL_DIR env.
- Updates symbolic entries and keys
- Gets editor session
- Adds date entry or file boilerplate, keeps boilerplate checksum
- Starts editor
- Remove unchanged boilerplate (files), or add changed files to GIT
'
htd__edit_today()
{
  htd_edit_today "$@"
}
htd_libs__edit_today=htd-main\ package\ date-htd\ journal\ doc\ htd-doc
htd_run__edit_today=lp


htd__edit_week()
{
  note "Editing $1"
  {
    htd_edit_week
  } || {
    error "ERR: $1/ $?" 1
  }
}


htd_man_1__today='Update yesterday, today and tomorrow and all current, prev
and next weekday links'
htd__today() # Jrnl-Dir YSep MSep DSep [ Tags... ]
{
  htd_jrnl_day_links "$@"
  htd_jrnl_period_links "$1" "$2"
}
htd_run__today=l
htd_libs__today=journal\ date-htd


htd_als__week_nr='Show current journal week/day id (ISO)'
htd__week_nr()
{
  date +%V
}


htd__this_week()
{
  test -n "$1" || set -- "$(pwd)/log" "$2"
  test -n "$2" || set -- "$1" "/"
  test -d "$1" || error "Dir $1 must exist" 1
  set -- "$(strip_trail "$1")" "$2"

  # Append pattern to given dir path arguments
  default_env W %Yw%V
  default_env WSEP /
  local r=$1$WSEP
  default_env EXT .rst
  set -- "$1$WSEP$W$EXT"

  datelink "" "$1" ${r}week$EXT
  datelink "-7d" "$1" "${r}last-week$EXT"
  datelink "+7d" "$1" "${r}next-week$EXT"
}
htd_grp__this_week=cabinet


htd_man_1__journal="Handle rSt log entries at archive paths

TODO: status check update

  update
  list [ Prefix=2... ]
      List entries with prefix, use current year if empty.
      Set to * for listing all entry.

  entries
      XXX: resolve metadata
"
htd__journal()
{
  test -n "$1" || set -- status
  case "$1" in

    status ) note "TODO: '$*'"
      ;;

    check ) note "TODO: '$*'"
      ;;

    update ) shift
        test -n "$1" || set -- $JRNL_DIR/entries.list
        htd__journal list '[0-9]*' |
            journal_index $CABINET_DIR $JRNL_DIR |
            journal_entries
        return
        #|
        #    htd__journal ids > $1.tmp

        c=$(count_lines "$1")
        enum_nix_style_file $1.tmp | while read n id line
        do
          printf -- "$id: $line idx:$n "
          test $n -gt 1 && {
            printf -- " prev:$(source_line $1.tmp $(( $n - l )) ) "
          }
          test $n -lt $c && {
            printf -- " next:$(source_line $1.tmp $(( $n + 1 )) ) "
          }
          echo
        done > $1

        rm $1.tmp
      ;;

    entries ) shift; journal_entries ;;

    ids ) shift; # Prefix paths with entry ID
        journal_index $CABINET_DIR $JRNL_DIR
      ;;

    list ) shift; # List entry names (no base-dir)
        test $# -gt 0 || set -- $(date +'%Y')
        ls ${CABINET_DIR}/$1{*/**,**}/journal.rst |
            cut -c$(( 2 + ${#CABINET_DIR} ))-
        ls ${JRNL_DIR}/$1**.rst | cut -c$(( 2 + ${#JRNL_DIR} ))-
      ;;

    list-paths ) shift; # List entry paths
        test $# -gt 0 || set -- $(date +'%Y')
        ls \
            ${CABINET_DIR}/$1{*/**,**}/journal.rst \
            ${JRNL_DIR}/$1**.rst
      ;;

    to-couch ) shift
        test -n "$1" || set -- $JRNL_DIR/entries.list
        htd__txt to-json "$1"
      ;;

    * ) error "'$1'? 'htd jrnl $*'" 1 ;;
  esac
}
htd_run__journal=l
htd_libs__journal=journal\ date-htd


htd_of__journal_json='json-stream'
htd__journal_json()
{
  test -n "$1" || set -- $JRNL_DIR/entries.list
  htd__txt to-json "$1"
}

htd_man_1__journal_times='
    list-day PATH
        List times found in log-entry at PATH.
    list-tri*
        List times for +/- 1 day (by alias).
    list-days TODO
    list-weeks TODO
    list-dir [Date-Prefix]
        paths with times
    TODO: list (-1) (+1) (dir|days|weeks)
    to-cal
'
htd__journal_times()
{
  set -euo pipefail
  # Move to journal-dir cd $HTDIR
  # Update links: htd__today personal/journal
  case "$1" in

    list-day )
        test -e $2 && sed -n 's/.*\[\([0-9]*:[0-9]*\)\].*/\1/gp' $2
      ;;

    list-tri* | list-triune )
        for p in personal/journal/today.rst personal/journal/tomorrow.rst \
          personal/journal/yesterday.rst
        do
          # Prefix date (from real filename), and (symbolic) filename
          htd__journal_times list-day $p |
            sed "s#^#$(basename $(readlink $p) .rst) #g" |
            sed "s#^#$p #g"
        done
      ;;

    list-days )
        note "TODO: $*"
      ;;
    list-weeks )
        note "TODO: $*"
      ;;

    list-dir )
        local p times
        for p in \
            ${CABINET_DIR}/${2-}[0-9]**/journal.rst \
            ${JRNL_DIR}/${2-}[0-9]*.rst
        do
          # Prefix date (from real filename), and (symbolic) filename
          times="$( htd__journal_times list-day $p | tr '\n' ' ' )"
          test -n "$times" || continue
          echo "$p $times"
          # |
          #   sed "s#^#$(basename $p .rst) #g" |
          #   sed "s#^#$p #g"
        done
      ;;

    list )
        test -n "$2" || set -- "$1" -1 +1 days
        test -n "$4" || set -- "$1" "$2" "$3" days
        case "$4" in
          dir )
              htd__journal_times list-dir "$2"
            ;;
          days )
              test "$2" = "-1" -a "$3" = "+1" &&
                htd__journal_times list-triune || htd__journal_times list-days "$2"
            ;;
          weeks )
              htd__journal_times list-week "$2"
            ;;
        esac
      ;;

    to-cal )
        # TODO: SCRIPT-MPE-4 cut down on events. e.g. put in 15min or 30min
        # bins. Add hyperlinks for sf site. And create whole-day event for days
        # w. journal entry without specific times
        shift
        local findevt=$(setup_tmpf .event)
        htd__journal_times list "$@" | while read file date time
        do
          gcalcli search --calendar Journal/Htd-Events "[$time] jrnl" "$date"\
            > $findevt
          grep -q No.Events.Found $findevt && {
            gcalcli add --details url --calendar Journal/Htd-Events \
              --when "$date $time"\
              --title "$(head -n 1 $file )" \
              --duration 10 \
              --where "+htdocs:personal/journal" \
              --description "[$time] jrnl" \
              --reminder 0 &&
                note "New entry $date $time" ||
                error "Entering $date $time for $file"
          } || {
            stderr info "Existing entry $date $time"
          }
        done
      ;;

    * ) error "jrnl-times '$1'?" 1 ;;
  esac
}

#
