#!/bin/sh

# Deal with (rich-text/plain format) document files.

doc_lib_load()
{
  lib_load match || return
  test -n "${DOC_EXT-}" || DOC_EXT=.rst
  test -n "${DOC_EXTS-}" || DOC_EXTS=".rst .md .txt .feature .html .htm"
  test -n "${DOC_MAIN-}" || DOC_MAIN="ReadMe main ChangeLog index doc/main docs/main"
}

doc_lib_init()
{
  test "${doc_lib_init-}" = "0" && return

  test -n "${package_log_doctitle_fmt-}" ||
      package_log_doctitle_fmt="%a, week %V. '%g"
  test -z "${package_lists_documents_exts-}" ||
      DOC_EXTS="$package_lists_documents_exts"

  test -n "${package_docs_find-}" || package_docs_find=doc_find_name
  test -n "${package_doc_find-}" || package_doc_find=doc_find_name

  spwd=.

  DOC_EXTS_RE="\\$(printf -- "$DOC_EXTS" | $gsed 's/\ /\\|\\/g')"
  DOC_MAIN_RE="\\$(printf -- "$DOC_MAIN" | $gsed -e 's/\ /\\|/g' -e 's/[\/]/\\&/g')"
}

doc_path_args()
{
  paths=$HTDIR
  test "$(pwd)" = "$HTDIR" || {
    paths="$paths ."
  }
}

# FIXME pass arguments as -iname query
doc_find_all()
{
  test -n "$package_docs_find" || doc_lib_init
  note "'$package_docs_find' '$*'"
  $package_docs_find "$@"
}

# FIXME pass arguments as -iname query
doc_find()
{
  test -n "$package_doc_find" || doc_lib_init
  # TODO: cleanup doc-find code
  #doc_path_args
  #test -n "$1" || return $?

  #info "Searching files with matching name '$1' ($paths)"
  #doc_find_name "$1"

  #info "Searching matched content '$1' ($paths)"
  #doc_grep_content "\<$1\>"

  test -n "$package_doc_find" || return $?
  $package_doc_find "$@"
}

# Find document,
doc_find_name()
{
  std_info "IGNORE_GLOBFILE=$IGNORE_GLOBFILE"
  local find_ignores="" find_=""

  find_ignores="-false $(find_ignores $IGNORE_GLOBFILE | tr '\n' ' ')"
  find_="-false $(for ext in $DOC_EXTS ; do printf -- " -o -iname '*$ext'" ; done )"

  # XXX: doc-find_path_args
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

doc_list_local()
{
  test -n "$package_lists_documents" ||
      package_lists_documents=doc-list-files-exts-re
  upper=0 mkvid "$package_lists_documents"
  ${vid}
}

doc_list_files_exts_re()
{
  spwd=. vc_tracked | grep '\('"$DOC_EXTS_RE"'\)$'
}

doc_main_files()
{
  for x in "" $DOC_EXTS
  do
    for y in $DOC_MAIN
    do
      for z in $y $(str_upper $y) $(str_lower $y)
      do
        test ! -e $z$x || printf -- "$z$x\\n"
      done
    done
  done
}

# Go over documents and cksums, and remove file if its md5sum matches exactly.
# Else add file to GIT. Some pattern skips the action for that file argument:
# '<*>' e.g. <noclean> <skip>
# The cksums list is build by htd-rst-doc-create-update for new boilerplates
htd_doc_cleanup_generated()
{
  foreach "$cksums" | {
      while test $# -gt 0
      do
        read cksum || error "No cksums left for '$1'" 1
        { fnmatch "<*>" "$cksum" || test ! -e "$1" ; } && { shift ; continue ; }
# allow editor to work on symbolic date paths but check-in actual file
        f="$(realpath "$1")"
        new_ck="$(md5sum "$f" | cut -f 1 -d ' ')"

        test "$cksum" = "$new_ck" && {
# Remove unchanged generated file, if not added to git
          git ls-files --error-unmatch "$f" >/dev/null 2>&1 || {
            rm "$f"
            note "Removed unchanged generated file ($f)"
          }
        } || {
          git add "$f"
        }
        shift
      done
    }
}

# Get first line if second line is all title adoration.
# FIXME: this misses rSt with non-content stuff required before title, ie.
# replacement roles, includes for roles, refs etc.
rst_doc_title()
{
  head -n 2 "$1" | tail -n 1 | $ggrep -qe "^[=\"\'-]\+$" || return 1
  head -n 1 "$1"
}

rst_docinfo() # Document Fieldname
{
  # Get field value (including any ':'), w.o. leading space.
  # No further normalization.
  $ggrep -m 1 -i '^\:'"$2"'\:.*$' "$1" | cut -d ':' -f 3- | cut -c2-
}

rst_docinfo_date() # Document Fieldname
{
  local dt="$(rst_docinfo "$@" | normalize_ws_str)"
  test -n "$dt" || return 1
  fnmatch "* *" "$dt" && {
    # TODO: parse various date formats
    error "Single datetime str required at '$1': '$dt'"
    return 1
  }
  echo "$dt"
}

rst_doc_date_fields() # Document Fields...
{
  local rst_doc="$1" ; shift
  rst_docinfo_inner() {
    rst_docinfo_date "$rst_doc" "$1" || echo "-"
  }
  act=rst_docinfo_inner foreach_do "$@"
}

# Double-join args Var_Id-Var_Id, remove ws. Convert each argument to name ID,
# and concatenate as a string-id.
args_to_filename() # Title-Descr
{
  while test $# -gt 0
  do
    mkid "$1" _ '%_-'
    test $# -gt 1 && echo "$id" || printf -- "%s" "$id"
    shift
  done | lines_to_words | tr ' ' '-'
}

# Separate each description with hyphen,
# TODO: unless some pattern is recognized. tags? todotxt?
args_to_title() # Title-Descr
{
  c=0
  { while test $# -gt 0
    do
      { context_exists "$1" || context_existsub "$1"
      } && {
        shift
        continue
      }

      test $c -eq 0 && {
        printf -- "%s \\n" "$1"
      } || {
      test $# -gt 1 && {
        printf -- " %s \\n" "$1"
      } || {
        printf -- " %s" "$1"
      };}
      incr_c
      shift
    done ; } | tr '\n' '-'
}

# Given a string(s), convert to ID and title
doc_title_id() # Title-Descr...
{
  doc_id="$(args_to_filename "$@")"
  note "Doc-Title-Id: Doc-Id: $doc_id"
  tags="$tags $( for t in "$@" ; do
          context_exists "$t" && echo "@$t" || {
          context_existsub "$t" && {
              context_subtag_env "$t" ; echo "@$tagid" ; } ; }
          continue ; done | lines_to_words | normalize_ws_str )"

  note "Doc-Title-Id: Tags: $tags"
  doc_title="$(args_to_title "$@")"
}
