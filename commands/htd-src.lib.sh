#!/bin/sh

# Created checkout at vendored path
htd_src_init() # domain ns name
{
  test -d "/src/$1/$2/$3" && return
  url="$(htd__gitremote url $1 $3)" || return $?
  test -n "$url" || return $?
  mkdir -vp "/src/$1/$2/"
  git clone $url "/src/$1/$2/$3"
}


htd_man_1__source='Generic sub-commands dealing with source-code. For Shell
specific routines see also `function`.

  source lines FILE [ START [ END ]]        Copy (output) from line to end-line.
  expand-source-line FILE LINENR
    Replace a source line with the contents of the sourced script

    This must be pointed to a line with format:

      .\ (P<sourced-file>.*)
'
htd__source()
{
  test -n "$1" || set -- copy
  case "$1" in

    lines ) shift
        test -e "$1" || error "file expected '$1'" 1
        source_lines "$@" || return $?
      ;;
    line ) shift
        test -e "$1" || error "file expected '$1'" 1
        source_line "$@" || return $?
      ;;
    copy ) shift
        htd__source lines "$3" "$1" "" "$2"
      ;;
    copy-where ) shift
        copy_where "$@"
      ;;
    cut-where ) shift
        cut_where "$@" || return $?
      ;;
    copy-paste ) shift
        test -z "$4" && cp_board=htd-source || cp=$4
        copy_only=false \
        copy_paste "$1" "$2" "$3" || return $?
        test -n "$4" || echo $cp
      ;;

    diff-where | sync-where ) shift
        diff_where "$@" || return $?
      ;;

    where-grep ) shift
        file_where_grep "$@" || return $?
        echo $line_number
      ;;

    where-grep-before ) shift
        file_where_before "$@" || return $?
        echo $line_number
      ;;

    where-grep-tail ) shift
        file_where_grep_tail "$@" || return $?
        echo $line_number
      ;;

    # XXX: ... No wrappers yet
    file-insert-at ) fail TODO ;;
    file-replace-at ) fail TODO ;;
    file-insert-where-before ) fail TODO ;;
    split-file-where-grep ) fail TODO ;;
    truncate ) fail TODO ;;
    truncate-lines ) fail TODO ;;
    # NOTE: see also htd function subcommand
    func-comment ) fail TODO ;;
    header-comment ) fail TODO ;;
    backup-header-comment ) fail TODO ;;
    list-functions ) fail TODO ;;
    # And many more in src.lib.sh

    expand-sentinel ) shift
        where_line="$(grep -nF "# htd source copy-paste: $2" "$1")"
        line_number=$(echo "$where_line" | sed 's/^\([0-9]*\):\(.*\)$/\1/')
        test -n "$line_number" || return $?
        expand_sentinel_line "$1" $line_number || return $?
      ;;
    expand-source-line ) shift ; expand_source_line "$@" ;;
    expand-include-sentinels ) shift ; expand_include_sentinels "$@" ;;

    * ) error "'$1'?" 1
      ;;
  esac
}


htd_man_1__function='Operate on specific functions in Sh scripts.

   copy FUNC FILE
     Retrieves function-range and echo function including envelope.
   copy-paste [ --{,no-}copy-only ] FUNC FILE
     Remove function from source and place in seperately sourced file
   start-line
     Retrieve line-number for function.
   range
     Retrieve start- and end-line-number for function.

See also
    src
    sync-func(tion)|diff-func(tion) FILE1 FUNC1 DIR[FILE2 [FUNC2]]
    sync-functions|diff-functions FILE FILE|DIR
    diff-sh-lib [DIR=$scriptpath]
'
htd__function() { false; }
htd_flags__function=l
htd_libs__function=htd-function


htd_man_1__diff_function='
  Compare single function from Sh script, to manually sync/update related
  functions in different files/directories. Normally runs vimdiff on a synced
  file. But quiet instead exists, and copy-only does not modify the source
  script but only shows the diff.  Normally (!copy-only) the two functions are
  replaced by a source command to their temporary file used for comparison,
  so that during editing the script remains fully functional.

  But meanwhile the both function versions are conveniently in separate files,
  for vimdiff or other comparison/sync tool.
'
htd_spc__diff_function="diff-func(tion) [ --quiet ] [ --copy-only ] [ --no-edit ] FILE1 FUNC1 DIR[FILE2 [FUNC2]] "
htd__diff_function()
{
  test -n "$1" -a -n "$2" -a -n "$3" || error "usage: $htd_spc__diff_function" 21
  test -n "$4" || {
    test -d "$3" -o -f "$3" || error "usage: $htd_spc__diff_function" 22
    test -f "$3" && {
      set -- "$1" "$2" "$3" "$2"
    } || {
      set -- "$1" "$2" "$3/$1" "$2"
    }
  }
  test -f "$1" -a -f "$3" || {
    stderr error "Missing files '$1' or '$3'"
    error "usage: $htd_spc__diff_function" 23
  }
  sh_isset quiet || quiet=false
  sh_isset sync || {
    trueish "$quiet" && sync=false || sync=true
  }
  sh_isset edit || edit=$sync
  sh_isset copy_only || {
    trueish "$sync" && copy_only=true || copy_only=false
  }

  lib_load functions

  # Extract both functions to separate file, and source at original scriptline
  mkid "$1" "" "_-" ; ext="$(filenamext "$1")"
  cp_board= ext="$id.$ext" copy_paste_function "$2" "$1" || { r=$?
    error "copy-paste-function 1 ($r)"
    return $r
  }
  test -s "$cp" || error "copy-paste file '$cp' for '$1:$2' missing" 1
  src1_line=$start_line ; start_line= ; src1=$cp ; cp=
  mkid "$3" "" "_-" ; ext="$(filenamext "$3")"
  cp_board= ext="$id.$ext" copy_paste_function "$4" "$3" || { r=$?
    # recover after error
    expand_source_line $1 $src1_line || error "expand-source-line 1" $?
    error "copy-paste-function 2 ($r)"
    return $r
  }
  test -s "$cp" || error "copy-paste file '$cp' for '$3:$4' missing" 1
  src2_line=$start_line ; start_line= ; src2=$cp ; cp=

  # Edit functions side by side
  trueish "$edit" && {
    diff -bqr $src1 $src2 >/dev/null 2>&1 &&
      stderr ok "nothing to do, '$2' in sync for '$1' $3'" || {
        vimdiff $src1 $src2 < /dev/tty &&
          stderr done "vimdiff ended" ||
          stderr error "vimdiff aborted, leaving unexpanded source lines" $?
      }
  } || {
    trueish "$quiet" && {
      diff -bqr $src1 $src2 >/dev/null 2>&1 && {
        stderr ok "in sync '$2'"
        echo "diff-function:$*" >> $passed
      } || {
        stderr warn "Not in sync '$2'"
        echo "diff-function:$*" >> $failed
      }
    } || {
      diff "$src1" "$src2"
      stderr ok "'$2'"
    }
  }
  trueish "$quiet" || {
    diff -bqr "$src1" "$src2" >/dev/null 2>&1 &&
    stderr debug "synced '$*'" ||
    stderr warn "not in sync '$*'"
  }

  trueish "$copy_only" || {
    # Move functions back to scriptline
    expand_source_line "$1" $src1_line || error "expand-source-line 1" $?
    expand_source_line "$3" $src2_line || error "expand-source-line 2" $?
  }
}
htd_flags__diff_function=iAO


htd_man_1__sync_function='Compare Sh functions using vimdiff. See diff-function,
this command uses:
  quiet=false copy-only=false edit=true diff-function $@
'
htd__sync_function()
{
  export quiet=false copy_only=false edit=true
  htd__diff_function "$@"
}
htd_flags__sync_function=iAO
htd_als__sync_func=sync-function

htd_man_1__diff_functions="List all functions in FILE, and compare with FILE|DIR

See diff-function for behaviour.
"
htd__diff_functions() # FILE FILE|DIR
{
  test -n "$1" || error "diff-functions FILE FILE|DIR" 1
  test -n "$2" || set -- "$1" $scriptpath
  test -e "$2" || error "Directory or file to compare to expected '$2'" 1
  test -f "$2" || set -- "$1" "$2/$1"
  test -e "$2" || { stderr info "No remote side for '$1'"; return 1; }
  test -z "$3" || error "surplus arguments: '$3'" 1
  lib_load functions
  functions_list $1 | sed 's/\(\w*\)()/\1/' | sort -u | while read -r func
  do
    grep -bqr "^$func()" "$2" || {
      warn "No function $func in $2"
      continue
    }
    htd__diff_function "$1" "$func" "$2" ||
        warn "Error on '$1:$func' <$2> ($?)" 1
  done
}
htd_flags__diff_functions=iAO


htd_man_1__sync_functions='List and compare functions.

Direct diff-function to be verbose, cut functions into separate files, use
editor for sync and then restore both functions at original location.
'
htd__sync_functions()
{
  export quiet=false copy_only=false edit=true
  htd__diff_functions "$@"
}
htd_flags__sync_functions=iAO


htd_man_1__diff_sh_lib='Look for local *.lib files, compare to same file in DIR.
  See {sync,diff}-functions for options'
htd_spc__diff_sh_lib='diff-sh-lib [DIR=$scriptpath]'
htd__diff_sh_lib()
{
  test -n "$1" || set -- $scriptpath
  test -d "$1" || error "Directory expected '$1'" 1
  test -z "$2" || error "surplus arguments: '$3'" 1
  list_functions_scriptname=false
  quiet=true
  for lib in *.lib.sh
  do
    note "Lib: $lib"
    htd__sync_functions $lib $1 || continue
  done
}
htd_flags__diff_sh_lib=iAO


htd_man_1__find_function='Get function matching grep pattern from files
'
htd_spc__find_function='find-function <grep> <scripts>..'
htd__find_function()
{
  func=$(first_match=1 find_function "$@")
  test -n "$func" || return 1
  echo "$func"
}


htd_man_1__filter_functions='
  Find and list all function and attribute declarations from Src-Files,
  filtering by one or more key=regex inclusively or exclusively. Output is
  normally a list of function names (out_fmt=names), or else all declaration
  lines (out_fmt=src).

  In inclusive mode one big grep-for is build from the filters and execution is
  done on each src with the accumulated result rewritten to unique function
  names, if requested (out-fmt=names).

  For exclusive mode, a grep for each filter is executed seperately against each
  source. With filter the resulting function-keys set is narrowed down, with
  then the resulting function keys being listed as is (out-fmt=names) or grepped
  from the source (out-fmt=src).

  Depending on the output format requested, more processing is done. The
  simplest format is names, followed by src. All other formats list beside the
  script-name, also the attributes values. However as some attributes may be
  multiline, they require additional source lookup to output.

  Other supported formats besides names and src are csv, json and yaml/yml.
  Each of these sources the source script and dereferences the required
  attribute values. '

htd_spc__filter_functions='filter-functions Attr-Filter [Src-Files...]'
htd__filter_functions() # Attr-Filter [Src-Files...]
{
  upper=false default_env out-fmt names
  title=true default_env Inclusive-Filter 1
  # With no filter env, use first argument or set default
  test -n "$Attr_Filter" || {
    test -n "$1" || { shift; set -- grp=box-src "$@"; }
    Attr_Filter="$1"
  }
  shift # first arg is ignored unless Attr_Filter is empty
  debug "Filtering functions from '$*' ($(var2tags Attr_Filter Inclusive_Filter ))"
  # sort out the keys from the filter into Filters, and export filter_$key env
  Filters=
  for kv in $Attr_Filter ; do
    k=$(get_kv_k "$kv") ; v=$(get_kv_v "$kv" filter_ $k)
    export filter_$k="$v" Filters="$Filters $k"
  done
  # Assemble grep args (inclusive mode) or grep-pattern lines (exclusive mode)
  Grep_For="$(
      for filter in $Filters ; do test -n "$filter" || continue
        trueish "$Inclusive_Filter" && printf -- "-e "
        printf -- "'^[a-z_]*_${filter}__.*=$(eval echo \"\$filter_${filter}\")' "
      done
    )"
  # Output function names to file, adding all declaration lines (inclusive mode)
  # or filtering out non-matching function-names (exclusive mode)
  local outf=$(setup_tmpf .out-$out_fmt-tmp)
  for src in "$@"
  do
    test -n "$src" || continue
    local func_keys=$(setup_tmpf .func-keys)
    {
      trueish "$Inclusive_Filter" && {
        eval grep $Grep_For $src |

          case "$out_fmt" in names )
              sed 's/^[a-z][a-z0-9_]*__\([^=(]*\).*$/\1/' ;;
          * )
              sed 's/^[a-z][a-z0-9_]*__\([^=(]*\).*$/\1/' > $func_keys
              eval grep "$( while read func_key ; do
                  printf -- "-e '^[a-z_]*__$func_key[=(].*' " ; done < $func_keys
                )" "$@"
            ;;
          esac
      } || {
        local src_lines=$(setup_tmpf .src-lines)
        grep  '^[a-z][a-z0-9_]*__.*[=(].*' "$src" > $src_lines
        for Grep_Rx in $Grep_For
        do
          mv $src_lines $src_lines.tmp
          eval grep $Grep_Rx $src | sed 's/^[a-z][a-z0-9_]*__\([^=(]*\).*$/\1/' > $func_keys
          test -s "$func_keys" || {
            warn "No matches for $Grep_Rx '$src'"
            return 1
          }
          # Remove functions declarations from src-lines where no matching func-keys
          eval grep "$( while read func_key ; do
              printf -- "-e '^[a-z][a-z0-9_]*__$func_key[=(].*' " ; done < $func_keys
            )" $src_lines.tmp > $src_lines
          rm $src_lines.tmp
        done

        case "$out_fmt" in
          names ) sed 's/^[a-z][a-z0-9_]*__\([^=(]*\).*$/\1/' $src_lines ;;
          * ) test -s "$src_lines" &&
              cat $src_lines || warn "Nothing found for '$src'"
            ;;
        esac
      }
    } | sed 's#^.*#'$src' &#'
  done > $outf
  test -s "$outf" && {
    cat $outf | htd_filter_functions_output
  } || {
    rm $outf
    return 1
  }
  rm $outf
}
htd_filter_functions_output()
{

  case "$out_fmt" in
    names ) tr '_' '-'  | uniq ;;
    src ) cat - ;;
    * ) cat - |
        sed 's/\([^\ ]*\)\ \([a-z][a-z0-9_]*\)__\([^(]*\)().*/\1 \3/g' |
        sed 's/\([^\ ]*\)\ \([a-z][a-z0-9_]*\)__\([^=]*\)=\(.*\)/\1 \3 \2 \4/g' |
        while read script_name func_name func_attr func_attr_value
        do # XXX: I whish I could replace this loop with a sed/awk/perl oneliner
          test -n "$func_attr_value" || {
            echo "$script_name $func_name" ; continue
          }
          echo "$script_name $func_name $(
              dsp=$(( ${#script_name} + 2 ))
              expr_substr "$func_attr" $dsp  $(( 1 + ${#func_attr} - $dsp ))
            ) $func_attr_value"
        done | sort -u | {
          case "$out_fmt" in
            csv )      htd_filter_functions_output_csv || return $? ;;
            yaml|yml ) htd_filter_functions_output_yaml || return $? ;;
            json )     htd_filter_functions_output_yaml | jsotk yaml2json - ||
              return $? ;;
          esac
        }
      ;;
  esac
}
htd_filter_functions_output_csv()
{
  local current_script=
  echo "# Script-Name, Func-Key, Func-Attr-Key, Func-Attr-Value"
  while read script_name func_key func_attr_key func_attr_value
  do
    test -n "$func_attr_value" || {
      test "$script_name" = "$current_script" || {
        export lib_loading=1
        source $script_name
        current_script=$script_name
      }
      continue
    }
    vid=$(lower=true str_word "$script_name")
    value="$( eval echo \"\$${vid}_${func_attr_key}__${func_key}\" )"
    fnmatch "*\n*\n*" "$value" &&
      value="$( echo "$value" | sed 's/$/\\n/g' | tr -d '\n' )"
    echo "$script_name,$func_key,$func_attr_key,\"$value\""
  done
}
htd_filter_functions_output_yaml()
{
  local current_script=
  while read script_name func_key func_attr_key func_attr_value
  do
    test "$script_name" = "$current_script" || {
      export lib_loading=1
      source $script_name
      echo "type: application/vnd.org.wtwta.box-instance"
      echo "script-name: $script_name"
      echo "command-functions:"
      current_script=$script_name
    }
    test -n "$func_attr_value" || {
      echo "  - subcmd: $(echo $func_key | tr '_' '-')"
      continue
    }
    vid=$(lower=true str_word "$script_name")
    value="$( eval echo \"\$${vid}_${func_attr_key}__${func_key}\" )"
    fnmatch "*\n*\n*" "$value" && {
      value="$(echo "$value" | jsotk encode -)"
      # FIXME: htd filter-functions out-fmt=yaml could use pretty multilines
      echo "    $(echo $func_attr_key | tr '_' '-'): $value"
    } || {
      echo   "    $(echo $func_attr_key | tr '_' '-'): '$value'"
    }
  done
}


htd__list_functions_added()
{
  filter=A htd__diff_function_names "$@"
}


htd__list_functions_removed()
{
  filter=D htd__diff_function_names "$@"
}


htd_man_1__diff_function_names='
  Compare function names in script, show changes
'
htd__diff_function_names()
{
  local version2=$2 version1=$1
  shift 2
  test -n "$1" || set -- "$(echo $scriptpath/*.sh)"
  test -n "$filter" || filter=A
  tmplistcur=$(setup_tmpf .func-list)
  tmplistprev=$(setup_tmpf .func-list-old)
  test -n "$version2" || version2=HEAD^
  {
    cd $scriptpath
    for name in $@
    do
      fnmatch "/*" "$name" &&
        name=$(echo "$name" | cut -c$(( 2 + ${#scriptpath} ))-)
      git show $version2:$name | list_functions_foreach |
        sed 's/\(\w*\)()/\1/' | sort -u > $tmplistprev
      test -n "$version1" && {
        note "Listing new fuctions at $version1 since $version2 in $name"
        git show $version1:$name | list_functions_foreach |
          sed 's/\(\w*\)()/\1/' | sort -u > $tmplistcur
      } || {
        note "Lising new fuctions since $version2 in $name"
        list_functions $name | sed 's/\(\w*\)()/\1/' | sort -u > $tmplistcur
      }
      case "$filter" in
        U ) comm_f=" -1 -2 " ;;
        A ) comm_f=" -2 -3 " ;;
        D ) comm_f=" -1 -3 " ;;
        * ) comm_f=" " ;;
      esac
      comm $comm_f $tmplistcur $tmplistprev
    done
  }
}

#
