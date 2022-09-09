#!/bin/sh
# Created: 2020-09-05
# 2020-09-07 Rewrote update-folder, edit-folder and rst-create/update.
# 2016-04-17 Renamed {vtoday,edit-today}
# 2016-03-28 Added vtoday


htd_man_1__journal="Handle rSt log entries at archive paths.

  edit [ 'next' | 'prev' ] [ 'week' | 'month' | 'year' | <WEEKDAY> | <MONTH> ] [BASE]
  edit [ <YEAR> [ 'w'<WEEK> | <MONTH> [ <DAY> ]]] [BASE]
  edit-week [WEEKNR [YEAR]] [BASE}
      Edit entry (year/month/week or day) by name or number, see edit-entry.

  edit-entry [ENTRY] [BASE]
      Edit entry (year/month/week or day) by ID. Edit current or given day,
      or given week, month or year and generate/cleanup card entries for
      current, next and previous entry.

  info PATH
      Print date/week/month info for cabinet or journal path.

  list [ Prefix=2... ]
      List entries with prefix, use current year if empty.
      Set to * for listing all entry.

  entries
      ..
"
# TODO: status check update htd:journal
# XXX: resolve metadata htd:journal:entries
htd__journal()
{
  test -n "${1-}" || set -- status
  case "$1" in

    update-folder ) shift; htd_jrnl_update_folder "$@" ;;
    #edit-folder ) shift; htd_jrnl_edit_folder "$@" ;;
    edit-entry ) shift; htd_jrnl_edit_entry "$@" ;;

    edit ) shift; local entry log
        test $# -gt 1 && {
            htd_jrnl_entry_spec "$@" || return
        } || entry=$(date +%F)
        htd_jrnl_edit_entry "$entry" "${log-}"
      ;;
    edit-today ) shift; htd_jrnl_edit_entry "" "${1-}" ;;
    edit-week ) shift;
        local year week log
        while test $# -gt 0
        do case "$1" in
            [0-9][0-9][0-9][0-9] ) test -z "${year-}" || return 98
                year=$1 ;;
            [0-9] | [0-9][0-9] ) test -z "${week-}" || return 98
                week=$1 ;;
            * ) test -n "${week-}" || return 98
                log=$1 ;;
        esac; shift; done
        true "${year:="$(date +%G)"}"
        htd_jrnl_edit_entry "$year-w$week" "${log-}" ;;


    status ) note "TODO: '$*'"
      ;;

    check ) note "TODO: '$*'"
      ;;

    info )
        case "$2" in
            cabinet/* )
                date=$(echo $2 | cut -d '/' -f2,3,4 --output-delimiter='-' ) ;;
            personal/journal/* ) date=$(basename $2 .rst) ;;
        esac
        year=$(echo $date | cut -d '-' -f 1)
        month=$(echo $date | cut -d '-' -f 2)
        date -d $date +"%c"
        date +"Sunday Week: %U" -d "$date"
        date +"ISO Week: %V" -d "$date"
        ncal -w $month $year
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
        echo FIXME: journal_index $CABINET_DIR $JRNL_DIR
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
htd_flags__journal=lp
htd_grp__journal=cabinet\ doc\ main
htd_libs__journal=sys-htd\ date-htd\ htd-main\ package\ context\ ctx-base\ ck\ $EDITOR


htd_of__journal_json='json-stream'
htd__journal_json()
{
  test -n "$1" || set -- $JRNL_DIR/entries.list
  htd__txt to-json "$1"
}


htd_man_1__journal_times='Filter journal date-tags

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
  # Move to journal-dir cd $HTDIR
  # Update links: htd__today personal/journal
  case "$1" in

    list-day )
        test -e $2 || return 98
        sed -n 's/.*\[\([0-9]*:[0-9]*\)\].*/\1/gp' $2
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


htd_man_1__today='Update yesterday, today and tomorrow and all current, prev
and next weekday links'
htd__today() # Jrnl-Dir [ Tags... ]
{
  htd_jrnl_update_folder "$1"
}
htd_flags__today=l
htd_libs__today=journal\ date-htd


htd_als__week_nr='Show current journal week/day id (ISO)'
htd__week_nr() # Date
{
  test $# -gt 0 || set -- now
  $LOG note "" "Weeknr is ISO (01-53)/Sunday-weeks (00-53)" "$(date +%V/%U -d "$1" )"
  date +%V -d "$*"
}

htd_grp__this_week=cabinet


# Create symlinks for today and every weekdays in last, current and next week,
# The document contents are initialized with htd-rst-doc-create-update
htd_jrnl_day_links () # Journal-Dir
{
  test -d "${1-}" || return 98
  fnmatch "*/" "$1" || set -- "$1/"

  # Append pattern to given dir path arguments
  local jr="$1" jfmt="$1$Y$YSEP$M$MSEP$D$EXT"
  files="${files:-}${files+" "}$( journal_create_day_symlinks "$jr" \
      "$jfmt" "$EXT" )"
}

# the symlinks for the week, month, and years (also -1 to +1)
htd_jrnl_period_links () # Journal-Dir
{
  test -d "${1-}" || return 98
  fnmatch "*/" "$1" || set -- "$1/"

  local jr="$1"
  files="${files:-}${files+" "}$( journal_create_period_symlinks "$jr" \
      "$jr%G-w%V$EXT" "$jr%G-%m$EXT" "$jr%G$EXT" )"
}

htd_jrnl_update_folder () # Journal-Dir
{
  test -d "${1-}" || return 98
  $LOG info "" "Updating symbolic links" "$1"
  test -n "${log-}" || {
    local $htd_log_keys
    htd_log_base_spec "${2-}" || return
  }

  # Prepare todays' day-links (including weekday and next/prev week, month, year)
  htd_jrnl_day_links "$1" || return
  htd_jrnl_period_links "$1" || return
}
  # FIXME: need offset dates from file or table with values to initialize docs

# Prepare files and cksums list for edit-and-update
htd_jrnl_edit_folder () # Journal-Dir [Entry]
{
  $LOG info "" "Preparing to edit folder" "$1"
  local current next prev d dfmt
  test -n "${2-}" && {
    local year yearnr month monthnr week weeknr date enddate daynr
    journal_date $(echo $2 | tr "\\$MSEP$YSEP" ' ')
    case "$p" in
        w ) dfmt=$Y${YSEP}w$W ;;
        m ) dfmt=$Y$YSEP$M ;;
        y ) dfmt=$Y ;;
    esac
  }
  true "${date:="today"}"
  true "${dfmt:="$Y$YSEP$M$MSEP$D"}"
  true "${p:="d"}"

  prev="$(date_fmt "$date -1$p" "$dfmt")"
  current="$(date_fmt "$date" "$dfmt")"
  next="$(date_fmt "$date +1$p" "$dfmt")"

  # Generate new documents, but only entries linked from current, prev and next
  local IFS_old="$IFS"
  IFS=$'\n'; for gen in $( IFS="$IFS_old";
        new= htd_jrnl_rst_create_update "$current" "$1" ;
        new= htd_jrnl_rst_create_update "$prev" "$1" ;
        new= htd_jrnl_rst_create_update "$next" "$1" ; ); do
    echo "$gen" | {
      IFS=$'\t' read entry log
      IFS="$IFS_old" new= htd_jrnl_rst_create_update "$entry" "$log" || return
    }
  done
  IFS=$IFS_old
}

htd_jrnl_rst_create_update () # Entry Base [parts]
{
  test $# -gt 1 -a -n "${1-}" || error "htd-jrnl-rst-create-update" 12
  local entry="$1" log_dir="$2" outf="$2$1$EXT" title ; shift 2
  true "${new:="$( test -s "$outf" && printf 0 || printf 1 )"}"

  local year yearnr month monthnr week weeknr date enddate daynr p
  journal_date $(echo $entry | tr "\\$YSEP$MSEP" ' ') || return

  fnmatch "*-entry" "${1-}" || case "$p" in
        w ) set -- week-entry "$@" ;;
        m ) set -- month-entry "$@" ;;
        y ) set -- year-entry "$@" ;;
        d ) set -- day-entry "$@" ;;
      esac

  test $new -eq 1 &&
        $LOG info "" "Generating $1..." "$1" ||
        $LOG info "" "Updating $1..." "$1"

  while test $# -gt 0 ;
  do case "$1" in

    year-entry ) test $# -gt 1 ||
          set -- "$1" title created updated default-rst link-year-up ;;
    month-entry ) test $# -gt 1 ||
          set -- "$1" title created updated default-rst link-month-up ;;
    week-entry ) test $# -gt 1 ||
          set -- "$1" title created updated default-rst link-week-up ;;
    day-entry ) test $# -gt 1 ||
          set -- "$1" title updated default-rst link-day-up ;;

    link-year-up )
          test $new -eq 1 || {
            error "XXX: Cannot add $1 to existing"
            shift; continue
          }
        ;;

    link-month-up )
          printf -- "$year\t$log_dir\n"

          test $new -eq 1 || {
            error "XXX: Cannot add $1 to existing"
            shift; continue
          }

          thisyearrel=$($grealpath --relative-to=$log_dir "$log_dir$year$EXT")
          {
            printf -- "  - \`$year <$thisyearrel>\`_\n"
          } >> $outf
        ;;

    link-week-up )
          grep -q '.. footer::' "$outf" || return 95

          printf -- "$year\t$log_dir\n"
          thismonth=$(date_fmt "$date" "%Y${YSEP}%m")
          printf -- "$thismonth\t$log_dir\n"

          test $new -eq 1 || {
            error "XXX: Cannot add $1 to existing"
            shift; continue
          }

          monthlbl="$(journal_title "" "$date" "m")"

          thismonthrel=$($grealpath --relative-to=$log_dir "$log_dir$thismonth$EXT")
          thisyearrel=$($grealpath --relative-to=$log_dir "$log_dir$year$EXT")
          {
            printf -- "  - \`$monthlbl <$thismonthrel>\`_\n"
            printf -- "  - \`$year <$thisyearrel>\`_\n"
          } >> $outf
        ;;

    link-day-up ) # Take day-entry and add links: this week, month and year
          grep -q '.. footer::' "$outf" || return 95

          printf -- "$year\t$log_dir\n"
          thismonth=$(date_fmt "$date" "%Y${YSEP}%m")
          printf -- "$thismonth\t$log_dir\n"
          thisweek=$(date_fmt "$date" "%G${YSEP}w%V")
          printf -- "$thisweek\t$log_dir\n"

          test $new -eq 1 || {
            error "XXX: Cannot add $1 to existing"
            shift; continue
          }

          weeklbl="$(journal_title "" "$date" "w")"
          monthlbl="$(journal_title "" "$date" "m")"

          thisweekrel=$($grealpath --relative-to=$log_dir "$log_dir$thisweek$EXT")
          thismonthrel=$($grealpath --relative-to=$log_dir "$log_dir$thismonth$EXT")
          thisyearrel=$($grealpath --relative-to=$log_dir "$log_dir$year$EXT")
          {
            printf -- "  - \`$weeklbl <$thisweekrel>\`_\n"
            printf -- "  - \`$monthlbl <$thismonthrel>\`_\n"
            printf -- "  - \`$year <$thisyearrel>\`_\n"
          } >> $outf
        ;;

    * ) local title=
          test "$1" != title && title= || title=$(journal_title "" "$date" "$p")
          htd_rst_doc_create_update "$outf" "$title" "$1" || return ;;

  esac ; shift ; done
}

htd_jrnl_edit_entry () # [Entry] [Base]
{
  local pwd="$(normalize_relative "$go_to_before")" \
      arg rst_default_include evoke_f

  test -n "${log-}" || {
    local $htd_log_keys
    htd_log_base_spec "${2-}" || return
  }
  set -- "${1-}" "$log"
  eval $(map=package_: package_sh rst_default_include)
  # Handle arguments wether log_dir-file or cabinet-path/archive-dir

  evoke_f="$(${EDITOR}_prepare_session edit-today 1.2-threepanes)"

  # Open dir generates symlinks and entry files
  test -d "$2" && {
    note "Editing folder $2..."
    local files cksums
    test -n "${1-}" || {
      # Generate symbolic links for current date
      htd_jrnl_update_folder "$2" || return
      files=$(filter_files $files)
    }

    # Prepare files for given or current date
    htd_jrnl_edit_folder "$2" "$1" || return

    files="$( { realpaths $2/today$EXT $2/week$EXT $2/month$EXT \
            $2/year$EXT $2/tomorrow$EXT $2/yesterday$EXT; \
           echo $files | words_to_lines; } | remove_dupes )"
    cksums="$(for sym in $files; \
      do test -e "$sym" && ck_md5 "$sym" || echo "<stage>"; done)"

    filecnt=$(echo $files | words_to_lines | count_words)
    ckcnt=$(echo $cksums | words_to_lines | count_words)
    test $filecnt -eq $ckcnt || error "A File/cksums: $filecnt/$ckcnt" 1

    # Start editor and stage/cleanup afterward
    local r
    htd_edit_and_update $files || r=$?
    test ${r-0} -eq 0 || error "during edit of $1 ($r)" 1
    return ${r-}
  }

  test -f "$1" && {
    note "Editing new entry $1..."
    # Open of archive file cause day entry added
    {
      local date_fmt="%Y${log_path_msep:-"-"}%m${log_path_dsep:-"-"}%d"
      local today="$(date_fmt "" "$date_fmt")"
      grep -qF $today $1 || printf "$today\n  - \n\n" >> $1
      $EDITOR $evoke_f $1
      git add $1
    } || {
      error "err file $?" 1
    }
    return $?
  }

  $LOG error "" "Nothing applicable" "$*"
}


htd_jrnl_entry_spec () # ["next" | "previous"] ( YEAR [ 'w'WEEK | MONTH ] | DAY NAME ) [ BASE ]
{
    local name offset p fmt tag
    fnmatch "* $1 *" " $journal_weekdays $journal_weekdays_abbrev " && {
        p=d name=$1
        shift
    } || {
        test $# -gt 1 && {
            case "$1" in
                last ) offset=-2; shift ;;
                next ) offset=+1; shift ;;
                -[0-9] | +[0-9] | -[0-9]*[0-9] | +[0-9]*[0-9] ) offset=$1; shift ;;
                * ) ;;
            esac
        }

        fnmatch "* $1 *" " $journal_weekdays $journal_weekdays_abbrev " && {
            p=d name=$1
            shift
        } || {
            fnmatch "* $1 *" " $journal_months " && {
                p=m name=$1
                shift
            } || {
                case "$1" in
                    week ) p=w ; shift ;;
                    month ) p=m ; shift ;;
                    year ) p=y ; shift ;;
                esac
            }
        }

    }

    test -n "${p-}" && {
        case "$p" in

            y ) name="${offset:-}${offset+"$p "}"
                fmt="%Y" ;;

            m ) name="${offset:-}${offset+"$p "}"
                fmt="%Y-%m" ;;

            w ) # TODO: how about dayname next/last/nth week?
                name="${offset:-}${offset+"$p "}"
                fmt="%G-w%V" ;;

            d )  # FIXME: this works with positive int+dayname but not negative.
                name="${offset:-}${offset+" "}$name"
                fmt="%Y-%m-%d" ;;
        esac

    } || {
        local year week month
        while test $# -gt 0
        do
            case "$1" in
                [0-9][0-9][0-9][0-9] ) year=$1; ;;
                w[0-9][0-9] ) week=$1 ;;
                [0-9] | [0-9][0-9] ) test -z "${month-}"  &&
                    month=$1 || entry=${year:-'%G'}-$month-$1; ;;
                * ) break ;;
            esac
            shift
        done
        test -n "${entry-}" || {
            test -n "${week-}" && {
                fmt="%G-w%V"
                entry=${year:-'%G'}-$week
            } || {
                test -n "${month-}" && {
                    fmt="%Y-%m"
                    entry=${year:-'%Y'}-$month-01
                } || {
                    test -n "${year-}" && {
                        entry=$year
                        fmt="%G"
                    } || {
                        $LOG error "" "args" "$*" 1
                    }
                }
            }
        }
        name=$(date_fmt "" "$entry")
    }
    entry=$(date_fmt "$name" "${fmt-"%Y-%m-%d"}")

    test $# -gt 0 && { log="$1"; shift; }
    test $# -eq 0 || return 98
}


htd_log_keys="log log_dir log_file log_path_ysep log_path_msep log_parts"
htd_log_env=""

htd_log_base_spec () # ~ [SPEC | PATH YSEP MSEP EXT # PARTS... ]
{
  # XXX: maybe use defaults if no package is found

  # test -n "${PACK_SH-}" -a -e "${PACK_SH-}" && {
  # Default to local log, or user's journal-dir setting
  #true ${log:="${log_dir:=$JRNL_DIR}/"}

  test -n "${1-}" && log="$1" || eval "$(map=package_: package_sh log)"
  test -n "${log-}" || { $LOG "error" "" "Expected package log"; return 1; }
  set -- $log
  test $# -gt 0 || return
  test $# -gt 1 && {
    log=$1 log_path_ysep="${2-}" log_path_msep="${3-}" log_path_ext="${4-}"
    test $# -le 4 || {
      test "${5-}" = "#" || return 98
      shift 5
      log_parts="$*"
    }
  } || {
    eval $(mkvid "$1" && map=package_logs_$vid: package_sh $htd_log_keys)
  }
  test -d "$1" && {
    fnmatch "*/" "$1" || set -- "$1/"
    log_dir="$1"
    log="$1"
  } || log_file="$1"
  YSEP="${log_path_ysep:="-"}"
  MSEP="${log_path_msep:="-"}"
  EXT="${log_path_ext:=".rst"}"
  # PARTS="${log_parts:="day-entry title updated default-rst"}"
  # FMT="${log_path_fmt:="${log_path_ext:1}"}"
  Y=%Y M=%m D=%d W=%V
}

#
