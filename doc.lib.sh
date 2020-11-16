#!/bin/sh

# Deal with (rich-text/plain format) document files.

doc_lib_load()
{
  test -n "${DOC_EXT-}" || DOC_EXT=.rst
  test -n "${DOC_EXTS-}" || DOC_EXTS=".rst .md .txt .feature .html .htm"
  test -n "${DOC_MAIN-}" || DOC_MAIN="ReadMe main ChangeLog index doc/main docs/main"
}

doc_lib_init()
{
  test "${doc_lib_init-}" = "0" && return
  lib_assert match || return

  test -n "${package_log_doctitle_fmt-}" ||
      package_log_doctitle_fmt="%a, week %V. '%g"
  test -z "${package_lists_documents_exts-}" ||
      DOC_EXTS="$package_lists_documents_exts"

  test -n "${package_docs_find-}" || package_docs_find=doc_find_name
  test -n "${package_doc_find-}" || package_doc_find=doc_find_name
  test -n "${package_lists_documents-}" || package_lists_documents=vc-exts-re

  DOC_EXTS_RE="\\$(printf -- "$DOC_EXTS" | $gsed 's/\ /\\|\\/g')"
  DOC_MAIN_RE="\\$(printf -- "$DOC_MAIN" | $gsed -e 's/\ /\\|/g' -e 's/[\/]/\\&/g')"
  DOC_EXTS_GLOB="{**/,}*.{$( set -- $DOC_EXTS; while test $# -gt 1; do printf "${1:1},"; shift; done; printf "${1:1}"; )}"
  DOC_EXTS_FNMATCH="$( set -- $DOC_EXTS; test $# -gt 1 && { printf -- '"*%s"' $1; shift; }; printf -- ' "*%s"' $@; )"
}

doc_path_args()
{
  paths=$HTDIR
  test "$PWD" = "$HTDIR" || {
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
  htd_find $PWD "$find_"
}

doc_grep_content()
{
  test -n "$1" || set -- .
  htd_grep_excludes
  match_grep_pattern_test "$PWD/"
  eval "grep -SslrIi '$1' $paths $grep_excludes" \
    | sed 's/'$p_'//'
}

# Execute package-lists-documents handler
doc_list_local()
{
  $LOG debug "" "Doc list local..." "$package_lists_documents"
  doc_list ${package_lists_documents} "$@"
}

# List all tracked files, filtering by DOC_EXTS_RE.
# Default doc-list-local handler (package-lists-documents setting)
doc_list ()
{
  local srcset=${1:-"default"} ; shift

  case "$srcset" in

      vc-exts-re ) vc_tracked "$@" | grep '\('"$DOC_EXTS_RE"'\)$' ;;

      # Does not work with Git
      vc-exts-glob )
           test $# -gt 0 || set -- $DOC_EXTS_GLOB
           files_list tracked "$@"
        ;;

      # Works with: Git
      vc-exts-fnmatch )
           test $# -gt 0 || eval set -- $DOC_EXTS_FNMATCH
           files_list tracked "$@"
        ;;

      * ) error "doc-list: Unknown src-set name '$srcset'" 1 ;;
  esac
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
  done | remove_dupes
}

# Go over documents and cksums, and remove file if its md5sum matches exactly.
# Else add file to GIT. Some pattern skips the action for that file argument:
# '<*>' e.g. <noclean> <skip>
# The cksums list is build by htd-rst-doc-create-update for new boilerplates
htd_doc_cleanup_generated()
{
  foreach "$cksums" | {
      local f cksum new_ck
      while test $# -gt 0; do read cksum || {
            error "No cksums left for '$1'" ; return 1 ; }

# Ignore <*> tags if file does not exist by now
        test -e "$1" || { shift ; continue ; }
        $LOG debug "" "Checking against $cksum..." "$1"

        fnmatch "<*>" "$cksum" && {
            shift; continue
        } || {
# allow editor to work on symbolic date paths but check-in actual file
            f="$(realpath "$1")"
            new_ck="$(ck_md5 "$f")"
        }

        test "$cksum" = "$new_ck" && {
# Remove unchanged generated file, if not added to git
          git ls-files --error-unmatch "$f" >/dev/null 2>&1 || {
            rm "$f"
            $LOG note "" "Removed unchanged generated file" "$f"
          }
        } || {
          git add "$f"
          $LOG note "" "Staged" "$f"
        }
        shift
      done
    }
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
      { context_exists_tag "$1" || context_exists_subtagi "$1"
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
      incr c
      shift
    done ; } | tr '\n' '-'
}

# Given a string(s), convert to ID and title using context.list
doc_title_id() # Title-Descr...
{
  doc_id="$(args_to_filename "$@")"
  note "Doc-Title-Id: Doc-Id: $doc_id"
  tags="$tags $( for t in "$@" ; do
          context_exists_tag "$t" && echo "@$t" || {
          context_exists_subtagi "$t" && {
              context_subtag_env "$t" ; echo "@$tagid" ; } ; }
          continue ; done | lines_to_words | normalize_ws_str )"

  note "Doc-Title-Id: Tags: $tags"
  doc_title="$(args_to_title "$@")"
}

#
