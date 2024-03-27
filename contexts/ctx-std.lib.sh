#!/bin/sh

ctx_std_defines=@Std
ctx_std_depends=@Base

at_Std()
{
  echo "Std (main entry-point) TODO: $*"
}

# Create std stat descriptor
docstat_init_std_descr()
{
  echo "${status:="-"}"
  test -e "$docstat_src" && {
    filemtime "$docstat_src"
  } || echo -
}

# Parse stat descriptor
docstat_parse_std_descr() # status mtime
{
  test $# -eq 2 || return 95
  test -z "${1-}" || status=$1
  test -z "${2-}" || mtime=$2
  export status mtime
}


scr__std__tags()
{
  std_info "Tags for '$scr_src' '$scr_file'"
  test -z "$*" || {
    words_to_lines "$@"
  }
  echo "$scr_tags"
  echo "$scr_tags_raw"

  # Get tags for source-file
  test -z "$scr_file" || {
    fnmatch "to/*" "$scr_file" && {
      lib_require tasks
      tasks_hub_tags "$scr_file"
    }
    package_lists_contexts_map "$scr_file"
    echo "<$( htd prefix name "$scr_file" )>"
  }

  #tag_default()
  #{
  #  fnmatch "* $1 *" " $scr_tags_raw " || echo "$1"
  #}
  #test -z "$1" || p= s= act=tag_default foreach_do "$@"
  #echo "$scr_tags_raw"

  #fnmatch "* sha1sum:* *" " $scr_tags_raw " || echo sha1sum:$sha1sum

  scr_ref="$( htd prefix name "$scr_file" )"
  fnmatch "* <$scr_ref> *" " $scr_tags" || echo "<$scr_ref>"

  #return 1
}


htd_ctx__std__list()
{
  try_context_actions list base -- "$@"
}

htd_ctx__std__init()
{
  try_context_actions init base -- "$@"
}

htd_ctx__std__check()
{
  try_context_actions check base -- "$@"
}

htd_ctx__std__process()
{
  try_context_actions process base -- "$@"
}

htd_ctx__std__update()
{
  try_context_actions update base -- "$@"
}

htd_ctx__std__update_status()
{
  test -n "$failed" -a ! -e "$failed" ||
      error "status: failed env missing or already exists" 1
  local scm= scmdir=
  vc_getscm && {
    vc_status || {
      error "VC getscm/status returned $?"
    }

    htd_vcflow_summary

    git grep '(TODO\|FIXME\|XXX\|BUG\|NOTE)'

  } || { # not an checkout

    # Monitor paths
    # Using either lsof or update/access time filters with find we can list
    # files and other paths that a user has/has had in use.
    # There are plenty of use-cases based on this.

    # See htd open-paths for local paths, using lsof.
    # CWD's end up being recorded in prefixes. With these we can get a better
    # selection of files.

    # Which of those are projects
    note "Open-paths SCM status: "
    htd__current_paths | while read p
    do verbosity=3
      { test -e "$p" && pd exists "$p"
      } || continue
      $LOG "header3" "$p" "$( cd "$p" && vc.sh flags )" "" >&2
    done

    # Projects can still have a large amount of files
    # opened, or updated recently.

    # Create list of CWD, and show differences on subsequent calls
    #htd__open_paths_diff

    # FIXME: maybe something in status backend on open resource etc.
    #htd__recent_paths
    #htd__active

    stderr note "text-paths for main-docs: "
    # Check main documents, list topic elements
    {
      test ! -d "$JRNL_DIR" || EXT=$DOC_EXT htd__archive_path $JRNL_DIR
      htd__main_doc_paths "$1"
    } | while read tag path
    do
      test -e "$path" || continue
      htd tpath-raw "$path" || warn "tpath-raw '$path'..."
    done
  }

  #htd_tasks_scan

  # TODO:
  #  global, local services
  #  disks, annex
  #  project tests, todos
  #  src, tools

  # TODO: rewrite to htd proj/vol/..-status
  #( cd ; pd st ) || echo "home" >> $failed
  #( cd ~/project; pd st ) || echo "project" >> $failed
  #( cd /src; pd st ) || echo "src" >> $failed

  #htd git-remote stat

  test -s "$failed" -o -s "$errored" && stderr ok "htd stat OK" || true
}
htd_ctx__std__update_status_old()
{
  # Go to project root
  cd "$workspace/$prefix"

  # Gather counts and sizes for SCM dir
  { test -n "$scm" || vc_getscm
  } && {

    htd_ws_stats_update scm "
$(vc_stats . "        ")" || return 1

    test -d "$workspace/$prefix/.$scm/annex" && {

        htd_ws_stats_update disk-usage "
              annex: $( disk_usage .$scm/annex)
              scm: $( disk_usage .$scm )
              (total): $( disk_usage )
              (date): $( date_microtime )" || return 1

      } || {

        htd_ws_stats_update disk-usage "
              scm: $( disk_usage .$scm )
              (total): $( disk_usage )
              (date): $( date_microtime )" || return 1
      }

  } || {

    htd_ws_stats_update disk-usage "
          (total): $( disk_usage )
          (date): $( date_microtime )" || return 1
  }

  # Use project metadata for getting more stats
  package_file "$workspace/$prefix" || return 0

  # TODO: Per project static code analysis
  #package_lib_set_local "."
  #. $PACK_SH

  #for name in $package_pd_meta_stats
  #do
  #  echo $name: $( verbosity=0 htd run $name 2>/dev/null )
  #done
}

htd_ctx__std__status()
{
  try_context_actions status base -- "$@"
}

htd_ctx__std__build()
{
  build -n "$package_std_build_bases" || package_std_build_bases=base
  try_context_actions build $package_std_build_bases -- "$@"
}

htd_ctx__std__test()
{
  test -n "$package_std_test_bases" || package_std_test_bases=base
  try_context_actions test $package_std_test_bases -- "$@"
}

htd_ctx__std__clean()
{
  test -n "$package_std_clean_bases" || package_std_clean_bases=base
  try_context_actions clean $package_std_clean_bases -- "$@"
}

ctx_std_property() #
{
  true
}

std_usage()
{
  ( try_local_func usage && $func_name ) ||
      ( try_local_func usage '' std && $func_name )
}

# Wrapper for try-help
std_man() # [Section] Id
{
  test -n "$*" || set -- man
  test $# -eq 1 && section= help_id="$1" || {
      test $# -eq 2 && section=$1 help_id="$2"
    }

  try_help "$section" "$help_id"
}

std_help()
{
  test -z "${1-}" && {
    std_usage
    # XXX: using compiled list of help ID since real list gets to long htd_usage
    echo ''
    echo 'Other commands: '
    other_cmds
    choice_global=1 std__help "$@"
    return
  }

  #test $# -eq 2 && section=$1 || section=1

  spc="$(try_spec $1)"
  test -n "$spc" && {
    echo "Usage: "
    echo "  $scriptname $spc"
    echo
  } || {
    printf "Help '%s %s': " "$scriptname" "$1"
  }

  echo_help $1 || {
    for func_id in "$1" "${base}__$1" "$base-$1"
    do
        htd_function_comment $func_id 2>/dev/null || continue
        htd_function_help $func_id 2>/dev/null && return 1
    done
    error "Got nothing on '$1'" 1
  }
}

std_man_1__help="Echo a combined usage and command list. With argument, seek all sections for that ID. "
std_spc__help='-h|help [ID]'
std_als___h=help
std__help()
{
  true "${box_prefix:="$(echo "$baseids" | cut -d' ' -f1)"}"

  test -z "${1-}" && {

    lib_load functions || return

    # Generic help (no args)
    try_exec_func ${box_prefix}__usage || std__usage
    try_exec_func ${box_prefix}__commands || std__commands
    try_exec_func ${box_prefix}__docs || true

  } || {

    # XXX: try_exec_func ${box_prefix}__usage $1 || { std__usage $1; echo ; }
    # Specific help (subcmd, maybe file-format other doc, or a TODO: group arg)
    spc="$(try_spec $1)"
    test -n "$spc" && {
      echo "Usage: "
      echo "  $scriptname $spc"
      echo
    }
    printf "Help '$1': "
    echo_help "$1" || error "no help '$1'"
  }
}

std__usage()
{
  test -z "${1-}" && {
    echo "$scriptname.sh Bash/Shell script helper"
    echo 'Usage:'
    echo "  $scriptname <cmd> [<args>..]"
  } || {
    printf "$scriptname $1: "
  }
  return 64
}

std__commands()
{
  test -n "${1-}" || set -- ${script-} ${box_lib-}
  test -n "${1-}" || set -- "$0"
  # group commands per file, using sentinal line to mark next file
  local list_functions_head="# file=\$file"

  trueish "${choice_global-}" || {
    trueish "${choice_all-}" || {
      local_id=$(pwd | tr '/-' '__')
      std_info "Local-ID: $local_id"
      echo 'Local commands: '$PWD': '
    }
  }

  lib_load functions || return

  test -z "${choice_debug-}" || echo "local_id=$local_id"
  list_functions_foreach "$@" | { local file
    while read -r line
    do
      # Check sentinel for new file-name
      test "$(expr_substr "$line" 1 1)" = "#" && {
        test "$(expr_substr "$line" 1 7)" = "# file=" && {

          file="$(expr_substr "$line" 8 ${#line})"
          test -e "$file" &&
              debug "std:commands File: $(basename "$file" .sh)" ||
              warn "std:commands No such file $file" 1
          local_file="$($grealpath --relative-to="$PWD" "$file")"

          # XXX: test -z "$local_id" && {
          #  # Global mode: list all commands
          #    test "$BOX_DIR/$base/$local_file" = "$file" && {
          #    echo "Commands: ($local_file) "
          #  } || {
          #    echo "Commands: ($file) "
          #  }
          #} || {
          #  # Local mode: list local commands only
          #  test "$local_file" = "${local_id}.sh" && cont= || cont=true
          #}
        } || continue
      } || true

      local subcmd_func_pref=${base}_
      if trueish "${cont-}"; then continue; fi

      func=$(echo $line | grep '^'${subcmd_func_pref}_ | sed 's/()//')
      test -n "$func" || continue

      func_name="$(echo "$func"| sed 's/'${subcmd_func_pref}'_//')"
      spc=

      if test "$(expr_substr "$func_name" 1 7)" = "local__"
      then
        lcwd="$(echo $func_name | sed 's/local__\(.*\)__\(.*\)$/\1/' | tr '_' '-')"
        lcmd="$(echo $func_name | sed 's/local__\(.*\)__\(.*\)$/\2/' | tr '_' '-')"
        test -n "$lcmd" || lcmd="-"
        #spc="* $lcmd ($lcwd)"
        spc="* $lcmd "
        descr="$(try_value ${subcmd_func_pref}man_1__$func_name)"
      else
        spc="$(try_value ${subcmd_func_pref}spc__$func_name)"
        descr="$(try_value ${subcmd_func_pref}man_1__$func_name)"
      fi
      test -n "$spc" || spc=$(echo $func_name | tr '_' '-' )

      test -n "$descr" || {
        test -s "${file-}" || {
          $LOG error "" "Did not get description or file" "fun:$func_name src:list-functions-foreach $*"
          continue
        }
        grep -q "^${subcmd_func_pref}${func_name}()" "$file" && {
          descr="$(func_comment "$subcmd_func_pref$func_name" "$file")"
        } || true
      }
      test -n "$descr" || descr=".." #  TODO: $func_name description"

        fnmatch *?"\n"?* "$descr" &&
          descr="$(printf -- "$descr" | head -n 1)"

      test ${#spc} -gt 20 && {
        printf "  %-18s\n                      %-50s\n" "$spc" "$descr"
      } || {
        printf "  %-18s  %-50s\n" "$spc" "$descr"
      }
    done
  }
}


std_als____version=version
std_als___V=version
std_man_1__version="Version info"
std_spc__version="-V|version"
std__version()
{
  test -n "${version-}" || exit 157
  test -e "${scriptpath:-$CWD}/.app-id" &&  {
    echo "$(cat $scriptpath/.app-id)/$version"
  } || {
    echo "$scriptname/$version"
  }
}

at_Std__at_Rules__trigger='*min *hours *days *weeks *months'
at_Std__at_Rules__trigger () # Id Spec
{
  test $# -eq 2 || return 64
  local seconds=
  case "$2" in
    *sec )    seconds=${2//sec/} ;;
    *min )    seconds=$(( 60 * ${2//min/} )) ;;
    *hours )  seconds=$(( 60 * 60 * ${2//hours/} )) ;;
    *days )   seconds=$(( 24 * 60 * 60 * ${2//days/} )) ;;
    *weeks )  seconds=$(( 7 * 24 * 60 * 60 * ${2//weeks/} )) ;;
    *months ) seconds=$(( 4 * 7 * 24 * 60 * 60 * ${2//months/} )) ;;
  esac

  test -s "$stat" || return 0
  newer_than "$out" "$seconds" && return 1 || return 0
}

#
