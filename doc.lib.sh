#!/bin/sh


doc_lib_load()
{
  lib_load list match
  test -n "$DOC_EXT" || DOC_EXT=.rst
  test -n "$DOC_EXTS" || DOC_EXTS=".rst .md .txt .feature .html .htm"
}


doc_path_args()
{
  paths=$HTDIR
  test "$(pwd)" = "$HTDIR" || {
    paths="$paths ."
  }
}

# Find document,
doc_find_name()
{
  info "IGNORE_GLOBFILE=$IGNORE_GLOBFILE"
  local find_ignores= find_=

  find_ignores="-false $(find_ignores $IGNORE_GLOBFILE | tr '\n' ' ')"
  find_="-false $(for ext in $DOC_EXTS ; do printf -- " -o -iname '*$ext'" ; done )"

  # XXX: doc_path_args
  htd_find $(pwd) "$find_"
}

doc_grep_content()
{
  test -n "$1" || set -- .
  htd_grep_excludes
  match_grep_pattern_test "$(pwd)/"
  eval "grep -SslrIi '$1' $paths $grep_excludes" \
    | sed 's/'$p_'//'
}


doc_main_files()
{
  for x in "" .txt .md .rst
  do
    for y in ReadMe main ChangeLog index doc/main docs/main
    do
      for z in $y $(str_upper $y) $(str_lower $y)
      do
        test ! -e $z$x || printf -- "$z$x\n"
      done
    done
  done
}

# Generate or update document file, and keep checksum for generated files
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
            relp="$(realpath --relative-to=$(dirname "$outf") $includedir)"
            {
              echo ; echo ; echo ".. include:: $relp/.default.rst"
            } >> $outf
          }
        ;;

      # Link up with period (week/month/Q/Y) stats files
      link-year-up )
          # Get year...
          thisyear=$(realpath "${log}${log_path_ysep}year$EXT")
          title="$(date_fmt "" "%G")"
          test -s "$thisyear" || {
            htd_rst_doc_create_update "$thisyear" "$title" \
                title created default-rst
          }
          # TODO htd_rst_doc_create_update "$thisyear" "" link-all-years
          grep -q '\.\.\ footer::' "$outf" || {
            thisyearrel=$(realpath --relative-to=$(dirname "$outf") "${log}${log_path_ysep}year$EXT")
            {
              printf -- ".. footer::\n\n\t- \`$title <$thisyearrel>\`_"
            } >> $outf
          }
        ;;

      link-month-up )
          # Get month...
          thismonth=$(realpath "${log}${log_path_ysep}month$EXT")
          title="$(date_fmt "" "%B %G")"
          test -s "$thismonth" || {
            htd_rst_doc_create_update "$thismonth" "$title" \
                title created default-rst link-year-up
          }
          # TODO: for further mangling need beter editor
          #{ test -n "$thisweek" && grep -Fq "$thisweekrel" "$outf"
          #} || {
          #  sed 's/.. htd journal week insert sentitel//'
          #}
          htd_rst_doc_create_update "$thismonth" "" link-year-up
          grep -q '\.\.\ footer::' "$outf" || {
            thismonthrel=$(realpath --relative-to=$(dirname "$outf") "${log}${log_path_ysep}month$EXT")
            {
              printf -- ".. footer::\n\n\t- \`$title <$thismonthrel>\`_"
            } >> $outf
          }
        ;;

      link-week-up )
          thisweek=$(realpath "${log}${log_path_ysep}week$EXT")
          title="$(date_fmt "" "%V week %G")"
          test -s "$thisweek" || {
            htd_rst_doc_create_update "$thisweek" "$title" \
                title created default-rst
          }
          htd_rst_doc_create_update "$thisweek" "" link-month-up
          grep -q '\.\.\ footer::' "$outf" || {
            thisweekrel=$(realpath --relative-to=$(dirname "$outf") "${log}${log_path_ysep}week$EXT")
            {
              printf -- ".. footer::\n\n\t- \`$title <$thisweekrel>\`_"
            } >> $outf
          }
        ;;

      link-day )
          # Get week...
          thisweek=$(realpath "${log}${log_path_ysep}week$EXT")
          title="$(date_fmt "" "Week %V, %G")"
          test -s "$thisweek" || {
            htd_rst_doc_create_update "$thisweek" "$title" \
                title created default-rst
          }
          htd_rst_doc_create_update "$thisweek" "" link-week-up

          #test $new -eq 1 || break ;
          grep -q '\.\.\ footer::' "$outf" || {
            thisweekrel=$(realpath --relative-to=$(dirname "$outf") "${log}${log_path_ysep}week$EXT")
            {
              printf -- ".. footer::\n\n\t- \`$title <$thisweekrel>\`_ "
            } >> $outf
          }
        ;;

    esac; shift
  done
  test -e "$outf" || touch $outf

  test $new -eq 0 || {
    note "New file '$outf'"
    export cksum="$(md5sum $outf | cut -f 1 -d ' ')"
    export cksums="$cksums $cksum"
  }
}

# Start EDITOR, after succesful exit cleanup generated files
htd_edit_and_update()
{
  test -e "$1" || error htd-edit-and-update-file 1

  $EDITOR "$@" || return $?

  new_ck="$(md5sum "$1" | cut -f 1 -d ' ')"
  test "$cksum" = "$new_ck" && {
    # Remove unchanged generated file, if not added to git
    git ls-files --error-unmatch $1 >/dev/null 2>&1 || {
      rm "$1"
      note "Removed unchanged generated file ($1)"
    }
  } || {
    git add "$1"
  }
}
