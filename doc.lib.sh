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


doc_find_name()
{
  find_ignores="-false $(find_ignores $IGNORE_GLOBFILE)"
  match_grep_pattern_test "$(pwd)"
  {
    test -z "$1" \
      && eval "find -L $paths $find_ignores -o \( -type f -o -type l \) -print" \
      || eval "find -L $paths $find_ignores -o -iname $1 -a \( -type f -o -type l \) -print"
  } | grep -v '^'$p_'$' \
    | sed 's/'$p_'\///'
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
      week )     test $new -eq 1 || break ;
            echo ":period: " >> $outf ;;
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

    esac; shift
  done
  test -e "$outf" || touch $outf

  test $new -eq 0 || {
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
