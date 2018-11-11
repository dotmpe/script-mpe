#!/bin/sh


# See also docstat-list XXX: see also doc-find, list from SCM etc.
htd_doc_list()
{
  doc_list_local
}

req_logdir_env()
{
  test -n "$log" || log="$package_log"
  test -n "$log" -a -d "$log" || error "package log env expected" 1
}

# Generate or update document file, and keep checksum for generated files
# Pure shell version.
htd_rst_doc_create_update()
{
  test -n "$1" || error htd-rst-doc-create-update 12
  local outf="$1" title="$2" ; shift 2
  test -s "$outf" && new=0 || new=1

  test $new -eq 1 || {

    # Document file exists, update
    updated=":\1pdated: $(date +%Y-%m-%d)"
    grep -qi '^\:[Uu]pdated\:.*$' $outf && {
      sed -i.bak 's/^\:\([Uu]\)pdated\:.*$/'"$updated"'/g' $outf
    } || {
      warn "Cannot update 'updated' field."
    }
  }

  # By default set title if given as argument,
  # to skip use any sensical argument ie. no-title
  test -z "$title" -o -n "$1" || set -- title

  while test -n "$1"
  do
    case "$1" in

      # Title always starts file, but only if required.
      title ) test $new -eq 0 || {
                # Use the basedir for the file-entry path to generate title
                test -n "$title" ||
                    title="$(basename "$(dirname "$(realpath "$outf")")")"
                echo "$title" > $outf
                echo "$title" | tr -C '\n' '=' >> $outf
            } ;;

      # Other arguments indicate lines to add to newly generated file
      created )  test $new -eq 1 || break ;
            echo ":created: $(date +%Y-%m-%d)" >> $outf ;;
      updated )  test $new -eq 1 || break ;
            echo ":updated: $(date +%Y-%m-%d)" >> $outf ;;
      default-rst ) test $new -eq 1 || break ;
            test -e .default.rst && {
            fnmatch "/*" "$outf" &&
              # FIXME: get common basepath and build rel if abs given
              includedir="$(pwd -P)" ||
              includedir="$(dirname $outf | sed 's/[^/]*/../g')"

            relp="$(grealpath --relative-to=$(dirname "$outf") $includedir)"
            {
              echo ; echo ; echo ".. include:: $relp/.default.rst"
            } >> $outf
          }
        ;;

      # Link up with period (week/month/Q/Y) stats files
      link-year-up )
          req_logdir_env
          # Get year...
          thisyear=$(realpath "${log}${log_path_ysep}year$EXT")
          title="$(date_fmt "" "%G")"
          test -s "$thisyear" || {
            # Recurse
            htd_rst_doc_create_update "$thisyear" "$title" \
                title created default-rst
          }
          # TODO htd_rst_doc_create_update "$thisyear" "" link-all-years
          grep -q '\.\.\ footer::' "$outf" || {
            thisyearrel=$(grealpath --relative-to=$(dirname "$outf") "${log}${log_path_ysep}year$EXT")
            {
              printf -- ".. footer::\n\n  - \`$title <$thisyearrel>\`_"
            } >> $outf
          }
        ;;

      link-month-up )
          req_logdir_env
          # Get month...
          thismonth=$(realpath "${log}${log_path_ysep}month$EXT")
          title="$(date_fmt "" "%B %G")"
          test -s "$thismonth" || {
            # Recurse
            htd_rst_doc_create_update "$thismonth" "$title" \
                title created default-rst link-year-up
          }
          # TODO: for further mangling need beter editor
          #{ test -n "$thisweek" && grep -Fq "$thisweekrel" "$outf"
          #} || {
          #  sed 's/.. htd journal week insert sentitel//'
          #}
          # Recurse
          htd_rst_doc_create_update "$thismonth" "" link-year-up
          grep -q '\.\.\ footer::' "$outf" || {
            thismonthrel=$(grealpath --relative-to=$(dirname "$outf") "${log}${log_path_ysep}month$EXT")
            {
              printf -- ".. footer::\n\n  - \`$title <$thismonthrel>\`_"
            } >> $outf
          }
        ;;

      link-week-up )
          req_logdir_env
          thisweek=$(realpath "${log}${log_path_ysep}week$EXT")
          title="$(date_fmt "" "%V week %G")"
          test -s "$thisweek" || {
            htd_rst_doc_create_update "$thisweek" "$title" \
                title created default-rst
          }
          htd_rst_doc_create_update "$thisweek" "" link-month-up
          grep -q '\.\.\ footer::' "$outf" || {
            thisweekrel=$(grealpath --relative-to=$(dirname "$outf") "${log}${log_path_ysep}week$EXT")
            {
              printf -- ".. footer::\n\n  - \`$title <$thisweekrel>\`_"
            } >> $outf
          }
        ;;

      link-day )
          req_logdir_env
          # Get week...
          thisweek=$(realpath "${log}${log_path_ysep}week$EXT")

          day="$( gdate +"%F" )"
          weekstart="$( gdate -d "$day -$(gdate -d $day +%u) days" +"%F" )"
          month_at_weekstart="$( gdate -d $day +%b )"

          title="$(date_fmt "" "Week %V, $month_at_weekstart %G")"

          test -s "$thisweek" || {
            htd_rst_doc_create_update "$thisweek" "$title" \
                title created default-rst
          }
          htd_rst_doc_create_update "$thisweek" "" link-week-up

          #test $new -eq 1 || break ;
          grep -q '\.\.\ footer::' "$outf" || {
            thisweekrel=$(grealpath --relative-to=$(dirname "$outf") "${log}${log_path_ysep}week$EXT")
            {
              printf -- ".. footer::\n\n  - \`$title <$thisweekrel>\`_"
            } >> $outf
          }
        ;;

    esac; shift
  done
  test -e "$outf" || touch $outf

  test $new -eq 0 && {
    export cksum=
    export cksums="$cksums <noclean>"
  } || {
    note "New file '$outf'"
    export cksum="$(md5sum $outf | cut -f 1 -d ' ')"
    export cksums="$cksums $cksum"
  }
}



# Build a new permalog entry, ie. a docpath that includes a date and that will
# exists indefinitely. Its content never changes, or not for a significant time.

htd_doc_new() # Title-Descr
{
  lib_load context ctx-base

  test -n "$title_fmt" || title_fmt="$package_log_doctitle_fmt"
  test -z "$1" && {

    # No filename for archive-path, build unique title/docid from calendar day
    test -n "$now" &&
        title="$(date_fmt "$now" "$title_fmt")" ||
        title="$(date_fmt "" "$title_fmt")"
    htd_doc_newfile "%a-%g_w%V" "$title" || return $?

  } || {

    # Tags given, look for % to expand (with stftime)
    eval set -- $( for a in "$@"
        do
          test "$a" = "%default" && { $gdate +"\"$title_fmt\"" ; continue ; }
          fnmatch "*%*" "$a" && $gdate +"\"$a\"" || echo \"$a\"
        done | lines_to_words )
    doc_title_id "$@" || return $?
    htd_doc_newfile "$doc_id" "$($gdate +"$doc_title")"
  }
}


htd_doc_newfile() # [date=now] . Title-Descr..
{
  test -n "$1" || error "Name-Id required" 1

  lib_load context ctx-base ctx-std

  #upper=0 mkvid "$package_permalog_method" ; method=$vid
  # doc_${method}_new "$@"

  # Parse pre-given filename to embed it in archive path
  fnmatch "*.*" "$1" && EXT=.$(filenamext "$1") ||  EXT="$DOC_EXT"

  # Process strftime placeholders before setting docid
  test -n "$now" &&
    docname="$(date_fmt "$now" "$(basename "$1" $EXT)")" ||
    docname="$($gdate +"$(basename "$1" $EXT)")"

  docstat_file_env "$docname" 1
  info "Doc-New Name-Id: $docstat_id"
  docstat_exists && warn "Entry exists '$docstat_id'" 1

  # Build strftime pathstr
  archive_path "$package_permalog_path/$1" "$now"
  note "Doc-New Path: $archive_path"

  # Create file and add docstat entry
  mkdir -p "$(dirname "$archive_path")"
  touch "$archive_path"
  req_logdir_env

  htd_rst_doc_create_update "$archive_path" "$2" title created
  docstat_src="$archive_path" ext=$(echo "$EXT" | cut -c2-) docstat_new "$2"

  test ! -e "$log/today.rst" || {

    # Append/insert file as rSt comment to todays entry
    jrnl_line=".. permalog $2 $archive_path"
    grep -q '^\s*\.\. ins.*' "$log/today.rst" && {
      file_insert_where_after '^\s*\.\.\ ins.*' "$log/today.rst" "$jrnl_line"
    } || {
      echo "$jrnl_line" >> "$log/today.rst"
    }
  }
}

# Start EDITOR, after succesful exit cleanup generated files
htd_edit_and_update()
{
  test -e "$1" || error htd-edit-and-update-file 1

  eval $EDITOR $evoke "$@" || return $?

  htd_doc_cleanup_generated "$@"
}

htd_log_current()
{
  for ptag in yesterday today tomorrow week month year
  do
     set -- "$package_log/$ptag.rst"
     test -e "$1" || continue
     echo "$1"
     continue
     #docstat_rst_tags "$1"
     du_dl_terms_paths "$1"
  done
}

htd_doc_check()
{
  PREFNAME=
  doc_list_local | while read -r doc
    do
        ext="$(filenameext "$doc")"
        docstat_check "$doc"
    done
}
