#!/bin/sh

du_lib_load()
{
  which rst2xml 1>/dev/null && rst2xml=$(which rst2xml) || {
    which rst2xml.py 1>/dev/null && rst2xml=$(which rst2xml.py) || {
      test -z "$DEBUG" || warn "No rst2xml"
    }
  }
echo rst2xml=$rst2xml >&2
}

du_proc()
{
  test -n "${warnings-}" || warnings=-
  # 1: info 2: warning 3: error 4 severe 5: disable exit status
  ~/project/docutils-mpe/tools/proc-mpe \
      --exit-status=3 \
      --quiet \
      --warnings="$warnings" "$1" || { r=$?
          $LOG error "" "du-proc" "$r"
          return $r
      }
}

du_getxml() # Process Du/rSt doc to XML ~ Du-Doc Xml-Doc
{
  test -n "${warnings-}" || warnings=-
  test -n "${warning_level-}" || warning_level=3
  test -n "${rst2xml-}" || error "rst2xml required" 1
  fnmatch '*.rst' $1 && {
    test -n "${2-}" || set -- "$1" "$sys_tmp/$(basename "$1" .rst).xml"
    test -e "$2" -a "$2" -nt "$1" || {
        std_info "rst2xml: $rst2xml $1 $2"
        $rst2xml \
          --exit-status=$warning_level \
          --quiet \
          --warnings="$warnings" "$1" "$2"
        export du_result=$?
    }
    export xml="$2"
  }
  test ! -s "$warnings" || error "Warnings during rst2xml <$warnings>"
  test -e "$2" || error "Need XML repr. for doc '$1'" 1
}

# Wrapper to adapt to every found instance for htdocs
du_dl_terms_paths () # RSt-Doc [Xml-Doc]
{
  # FIXME: move to functions, output needs a bit cleaning up
  {
    du_dl_term_paths "$@"
    # htd tpaths "$1"
  } | sed \
      -e 's/ /-/g' \
      -e 's/&gt;[-]*/>/g' \
      -e 's/&lt;/'"\\n"'</g' \
      -e 's/^\//@/g' \
      -e 's/"//g'
}

du_dl_term_paths_raw() # Retrieve Du definition outline as a relative path ~ Du-Doc Xml-Doc
{
  test -e "${2-}" || {
    du_getxml "$1" "${2-}" || return
    set -- "$1" "$xml"
  }

    # std_info "File '$(basename "$1")' already in catalog"
  # Read multi-leaf relative path for each file
  {
    test -n "${xsl_ver:-}" || htd_load_xsl
    case "$xsl_ver" in

      1 ) htd_xproc "$2" $scriptpath/rst-terms2path.xsl ;;

      2 ) htd_xproc2 "$2" $scriptpath/rst-terms2path-2.xsl ;;

      * ) error "xsl-ver '$xsl_ver'" 1 ;;
    esac

  # split each relative path to its own line
  } | grep -Ev '^(#.*|\s*)$' \
    | sed 's/\([^\.]\)\/\.\./\1\
../g' \
    | grep -v '^\.[\.\/]*$'
}

du_dl_term_paths() # Normalize relative path from dl-terms-paths-raw ~ Du-Doc Xml-Doc
{
  du_dl_term_paths_raw "$1" "${2-}" | while read -r rel_leaf
  do
    # FIXME: Assemble each leaf path onto its root, and normalize
    echo "$rel_leaf" | grep -q '^\.\.\/' && {
      path="$(normalize_relative "$path/$rel_leaf")"
    } || {
      path="$(normalize_relative "$rel_leaf")"
    }

    # Columns to print
    trueish "${print_baseid-}" && {
      filename_baseid "$1"
      printf -- "$id "
    }

    trueish "${print_src-}" && {
      printf -- "$1 "
    }

    echo "$path"

  done
}

# Get metadata that is either expressed as docinfo, or part of mode-line
# comment.
# Id|Version|Language|Tags
du_get_param () #
{
  false
}
