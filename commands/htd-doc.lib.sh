#!/bin/sh

htd_man_1__doc='Wrapper for documents modules (doc.lib and htd-doc.lib)

  list [Docstat-Glob] - run
  count [Docstat-Glob] - run
  new [Title|Descr|Tags...]

See also docstat.lib
'
htd_flags__doc=fpql
htd_libs__doc=doc\ htd-doc\ context\ ctx-base\ files
htd__doc()
{
  test $# -eq 1 -o -n "${1-}" || set -- main-files
  subcmd_prefs=${base}_doc_\ doc_ try_subcmd_prefixes "$@"
}

htd_man_1__count="Look for doc and count. "
htd_spc__count="count"
htd__count()
{
  test $# -eq 1 -a -n "${1-}" || set -- "" # return
  doc_path_args

  stderr info "Counting files with matching name '$1' ($paths)"
  doc_find_name "$1" | wc -l

  stderr info "Counting matched content '$1' ($paths)"
  doc_grep_content "$1" | wc -l
}
htd_grp__count=doc\ htd-list
htd_libs__count=list\ ignores\ package
htd_flags__count=lq


htd_man_1__find_doc="Look for document.

TODO: get one document
"
htd_spc__find_doc="-F|find-doc (<path>|<localname> [<project>])"
htd__find_doc()
{
  doc_find "$@"
}
htd_als___F=find-doc
htd_flags__find_doc=lx
htd_libs__find_doc=doc


htd_man_1__find_docs='Find documents

TODO: find doc-files, given local package metadata, rootdirs, and file-extensions
XXX: see doc-find-name
XXX: replace pwd basename strip with prefix compat routine
'
htd_spc__find_docs='find-docs [] [] [PROJECT]'
htd__find_docs()
{
  doc_find_all "$@"
}
htd_flags__find_docs=pqlx
htd_libs__find_docs=doc

# See also docstat-list XXX: see also doc-find, list from SCM etc.
htd_doc_list ()
{
  doc_list_local "$@"
}

htd_doc_count ()
{
  doc_list_local | count_lines
}

# Frontend for -htd-doc-query-or-create-or-edit, see htd-doc-new for info.
htd_doc_exists() # Title-Descr...
{
  lib_load context ctx-base
  query=1 _htd_doc_query_or_create_or_edit "$@"
}

# Frontend for -htd-doc-query-or-create-or-edit, see htd-doc-new for info.
htd_doc_edit() # Title-Descr...
{
  lib_load context ctx-base
  edit=1 _htd_doc_query_or_create_or_edit "$@"
}

# Build a new permalog entry, ie. a docpath that includes a date and that will
# exists indefinitely. Its content never changes, or not for a significant time.
#
# rst title and created fields builtin. enters entry into docstat, and adds
# permalog pseudo-directive to journal:today file.
#
# Frontend for -htd-doc-query-or-create-or-edit
htd_doc_new() # Title-Descr...
{
  lib_load context ctx-base
  create=1 edit=1 _htd_doc_query_or_create_or_edit "$@"
}


# Get archived path for given title-descr, create and/or start editor for path,
# this wraps htd-doc-file and doc-title-id for Title-Descr to doc-id.
_htd_doc_query_or_create_or_edit() # [query=] [create=] [edit=] ~ [Title-Descr...]
{
  test -n "${title_fmt-}" || title_fmt="$package_log_doctitle_fmt"
  test -z "${1-}" && {

    # No filename for archive-path, build unique title/docid from calendar day
    test -n "$now" &&
        title="$(date_fmt "$now" "$title_fmt")" ||
        title="$(date_fmt "" "$title_fmt")"
    htd_doc_file "%a-%g_w%V" "$title" || return $?

  } || {

    # Tags given, look for % to expand (with stftime)
    eval set -- $( for a in "$@"
        do
          test "$a" = "%default" && { $gdate +"\"$title_fmt\"" ; continue ; }
          fnmatch "*%*" "$a" && $gdate +"\"$a\"" || echo \"$a\"
        done | lines_to_words )
    doc_title_id "$@" || return $?
    htd_doc_file "$doc_id" "$($gdate +"$doc_title")"
  }
}


# Build path to document file, each argument corresponding to a topic or title,
# and being concatenated for document filename and title entry. But formatted
# according to use, with no arguments set to calendar day for [date].
#
# Without create or edit env settings then query=1.
# Otherwise ff query set then create=0 edit=0.
#
# TODO: unify package-permalog-method settings
htd_doc_file() # [date=now] [query=] [edit=] [create=] ~ [Title-Descr..]
{
  test -n "$1" || error "Name-Id required" 1
  test -n "$htd_doc_init_fields" || htd_doc_init_fields="title created"

  #upper=0 mkvid "$package_permalog_method" ; method=$vid
  # doc_${method}_new "$@"

  # Parse pre-given filename to embed it in archive path
  fnmatch "*.*" "$1" && EXT=.$(filenamext "$1") ||  EXT="$DOC_EXT"

  # Process strftime placeholders before setting docid
  test -n "$now" &&
    docname="$(date_fmt "$now" "$(basename "$1" $EXT)")" ||
    docname="$($gdate +"$(basename "$1" $EXT)")"

  docstat_file_env "$docname" 1

  test -z "$query" -a -z "$create" -a -z "$edit" &&
      eval query=1 create=0 edit=0 || {
    trueish "$query" && eval create=0 edit=0
  }

  trueish "$create" && {
    docstat_exists && warn "Entry exists '$docstat_id'" 1
    std_info "Doc-New Name-Id: $docstat_id"
  }

  # Build strftime pathstr
  archive_path "$package_permalog_path/$1" "$now"
  note "Doc Path: $archive_path"

  # Create file and add docstat entry
  trueish "$create" && {
      mkdir -p "$(dirname "$archive_path")"
      touch "$archive_path"
  }
  req_logdir_env

  test -e "$archive_path" && {
    htd_rst_doc_create_update "$archive_path" "$2" $htd_doc_init_fields
  }
  trueish "$create" && {
    docstat_src="$archive_path" ext=$(echo "$EXT" | cut -c2-) docstat_new "$2"
  }
  note "c:$create q:$query e:$edit path: $archive_path"

  trueish "$query" && {

    test -e "$archive_path" || return
    echo $archive_path
    return
  }
  trueish "$edit" || return 0
  test -e "$archive_path" || return
  cabinet_permalog "$log/today.rst" "$docstat_id" "$archive_path"
  $EDITOR "$archive_path"
}

# Start EDITOR, after succesful exit cleanup generated files
htd_edit_and_update() # [evoke_f] [cksums] ~ FILES...
{
  test -e "${1-}" || error htd-edit-and-update-file 1

  eval $EDITOR $evoke_f "$@" || return $?

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
        # ext="$(filenamext "$doc")"
        docstat_assert_entry "$doc"
    done
}

# Generate or update document file, and keep checksum for generated files.
# XXX: this is getting a bit longish, should split up specific rst-doc fields
# and allow them to be overriden.
htd_rst_doc_create_update () # OUTFILE TITLE [PARTS... | "title"]
{
  test $# -gt 1 -a -n "${1-}" || error "htd-rst-doc-create-update" 12
  local outf="$1" title="$2" ; shift 2
  true "${new:="$( test -s "$outf" && printf 0 || printf 1 )"}"
  test -z "$title" -o $# -gt 0 || set -- title

  # XXX: fix title echo $outf $title $* >&2
  while test $# -gt 0 ; do case "$1" in

      # Title always starts file, but only if required.
      title ) test $new -eq 0 && {
              # TODO: update title
              true
              # test "$(head -n 1 "$outf"|tr -d '\n')" = "$title" ||

            } || {

              # Use the basedir for the file-entry path to generate title
              test -n "$title" ||
                  title="$(basename "$(dirname "$(realpath "$outf")")")"
              echo "$title" >"$outf"
              echo "$title" | tr -C '\n' '=' >>"$outf"
            } ;;

      # Other arguments indicate lines to add to newly generated file
      created )  test $new -eq 1 &&
            echo ":created: $(date +%Y-%m-%d)" >>"$outf" || true ;;

      updated ) test $new -eq 1 && {
            echo ":updated: $(date +%Y-%m-%d)" >>"$outf"
          } || {
            updated=":\1pdated: $(date +%Y-%m-%d)"
            grep -qi '^\:[Uu]pdated\:.*$' $outf && {
              sed -i.bak 's/^\:\([Uu]\)pdated\:.*$/'"$updated"'/g' "$outf"
              rm "$outf.bak"
            } || warn "Cannot update 'updated' field <$outf>"
          }
        ;;

      # TODO: Read custom default include-mode per package, set to absolute
      # global file or local name to look for. #ZrFk88Dd
      include ) test $new -eq 1 && {
            local relp="$($grealpath --relative-to=$(dirname "$outf") $rstinc)"
            {
              echo ; echo ; echo ".. insert:" ; echo ".. include:: $relp"
            } >> $outf
          }
        ;;

      default-rst ) test $new -eq 1 && {
            test -n "${package_sh_rst_default_include-}" ||
                package_sh_rst_default_include=.default.rst # FIXME: package pd-meta defaults elsewhere

            # Use local package to set document include mode #H-ZHgcmF
            test -e "$package_sh_rst_default_include" && {
              local rstinc="$package_sh_rst_default_include"

              #fnmatch "/*" "$rstinc" &&
              #    rstinc=$($grealpath --relative-to=)

              #fnmatch "/*" "$outf" &&
              #  # FIXME: get common basepath and build rel if abs given
              #  includedir="$(pwd -P)" ||
              #  includedir="$(dirname $outf | sed 's/[^/]*/../g')"

              local relp="$($grealpath --relative-to=$(dirname "$outf") $rstinc)"
              {
                echo ; echo ; echo ".. insert:" ; echo ".. include:: $relp"
              } >> $outf
            }

            printf -- ".. footer::\n\n" >> $outf
          } || true
        ;;

      link-stats )
        ;;

      * ) $LOG error "" "No such rst part '$1'"; return 1 ;;

  esac ; shift ; done
}

htd_man_1__tpaths='List topic paths (nested dl terms) in document paths.

See du:dl-term-paths and also htd:tpath-raw
'
htd_flags__tpaths=l
htd_load__tpaths=xsl
htd_libs__tpaths=du
htd__tpaths()
{
  test $# -gt 0 || error "At least one document expected" 1
  test -n "${print_src:-}" || local print_src=0
  test -n "${print_baseid:-}" || local print_baseid=0

  test $# -gt 1 || {
    du_dl_term_paths "$1"
    return $?
  }

  act=du_dl_term_paths foreach_do "$@"
}
htd_vars__tpaths="path rel_leaf root xml"

htd_load__tpath_raw="xsl"
htd__tpath_raw()
{
  test $# -gt 0 -a -n "$1" || error "document expected" 1
  test -e "$1" || error "no such document '$1'" 1

  test $# -gt 1 || {
    du_dl_term_paths_raw "$1"
    return $?
  }

  act=du_dl_term_paths_raw foreach_do "$@"
}

#
