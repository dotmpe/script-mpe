#!/bin/sh

functions_lib_load()
{
  #which -s "coffee" && {
  #  # Use NPM bash-parser to try and get command/function calls from src
  #  sh_list_calls="coffee $(lookup_path PATH sh.coffee | head -n1)"
  #} ||
  test -n "$cllct_src_base" || cllct_src_base=.cllct/src
  test -n "$src_stat" || src_stat=$HOME/bin/$cllct_src_base
}

# List all function declaration lines found in given source, or current executing
# script. To match on specific names instead, see find-functions.
functions_list() # (ls-func|list-func(tions)) [ --(no-)list-functions-scriptname ]
{
  test -z "$2" || {
    # Turn on scriptname output prefix if more than one file is given
    var_isset list_functions_scriptname || list_functions_scriptname=1
  }
  list_functions_foreach "$@"
}

functions_ranges()
{
  test -n "$2" && multiple_srcs=1 || multiple_srcs=0
  functions_list "$@" | while read a1 a2 ; do
    test -n "$a1" -o -n "$a2" || continue
    test -n "$a2" && { f=$a2; s=$a1; } || { f=$a1; s=$1; }
    f="$(echo $f | tr -d '()')" ; upper=0 mkvid "$f"
    r="$(eval scrow regex --rx-multiline --fmt range \
      "$s" "'^$vid\\(\\).*((?<!\\n\\})\\n.*)*\\n\\}'")"
    trueish "$multiple_srcs" && echo "$s $f $r" || echo "$f $r"
  done
}

functions_filter_ranges()
{
  test -n "$3" && multiple_srcs=1 || multiple_srcs=0
  upper=0 default_env out-fmt xtl
  out_fmt=names htd__filter_functions "$@" | while read a1 a2
  do
    test -n "$a1" -o -n "$a2" || continue
    test -n "$a2" && { f=$a2; s=$a1; } || { f=$a1; s=$2; }
    upper=0 mkvid "htd__$(echo $f | tr -d '()')"
    r="$( eval scrow regex --rx-multiline --fmt $out_fmt \
      "$s" "'^$vid\\(\\).*((?<!\\n\\})\\n.*)*\\n\\}'")"
    test -n "$r" || { warn "No range for $s $f"; continue; }
    case "$out_fmt" in xtl ) echo $r ;;
      * ) trueish "$multiple_srcs" && echo "$s $f $r" || echo "$f $r" ;;
    esac
  done
}

# List function calls, ignoring executable scriptnames not on PATH
# Print real exec script path and SRC-script.
functions_execs() # SRC...
{
  list_sh_calls_foreach "$@" | sort -u | while read -r script cmd
    do
      which -s "$cmd" || continue
      echo "$(realpath "$(which "$cmd")") $script"
    done | join_lines
}

functions_cmdnames()
{
  { list_sh_calls_foreach "$@" || return $?; } | sort -u
}

functions_calls()
{
  lib_load build # XXX: for sh-calls, move to sep. lib later

  functions_list "$@" | sed 's/().*$//g' | while read -r func
  do
    printf -- "$1 $func "
    {
      copy_function "$func" "$1" | list_sh_calls_foreach -

    } | remove_dupes | lines_to_words
    echo
  done
}

# Scan for calls using target list
text_lookup() # SOURCES TARGETS [FUNC_TAB]
{
  test -n "$1" || set -- $cllct_src_base/call-graph/sources.txt "$2" "$3"
  test -n "$2" || set -- "$1" $cllct_src_base/call-graph/targets.txt "$3"
  test -n "$3" || set -- "$1" "$2" $cllct_src_base/functions.list
  local SOURCES=$1 TARGETS=$2

  mkdir -p "$(dirname "$1")"
  test -e "$3" || { functions_list *.sh | sed 's/().*$//g' > "$3" ; }
  test -e "$2" || { cut -d' ' -f2  "$3" | sort -u >"$2" ; }
  test -e "$1" || { cut -d' ' -f1  "$3" | sort -u >"$1" ; }

  for file in `cat $SOURCES `
  do
    for target in `ggrep -v -E '^ *#' $file | ggrep -o -F -w -f $TARGETS | ggrep -v -w $file | sort | uniq`
    do echo $file $target
    done
  done
}


# List names of functions/commands called by scripts
list_sh_calls()
{
  #$sh_list_calls "$@" || $_failed_ "$*"
  test -n "$*" || error "list-sh-calls: pathnames expected" 1
  $HOME/project/oil/bin/oshc deps "$@" --chained-commands="sudo time" | cat
}

list_sh_calls_foreach()
{
  note "List-Sh-Calls-Foreach: '$*'"
  list_sh_calls_foreach_inner()
  {
    list_sh_calls "$1" | sort -u | sed 's#^#'"$1"' #'
  }
  p= s= act=list_sh_calls_foreach_inner foreach_do "$@"
}
