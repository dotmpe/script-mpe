#!/bin/sh
# Created: 2016-01-09
# Htd support lib, see also htd-* libs


htd_lib__load()
{
  test -n "${NS_NAME-}" || NS_NAME=dotmpe
}


# Set XSL-Ver if empty. See htd tpaths
htd_load_xsl()
{
  test -z "${xsl_ver-}" && {
    test -x "$(which saxon)" && xsl_ver=2 || xsl_ver=1
  }
  test xsl_ver != 2 -o -x "$(which saxon)" ||
      $LOG error "" "Saxon required for XSLT 2.0" "" 1
  $LOG info "" "Set XSL proc version=$xsl_ver.0"
}

htd_xproc()
{
  {
    fnmatch '<* *>' "$2" && {

      xsltproc --novalid - $1 <<EOM
$2
EOM
    } || {
      xsltproc --novalid $2 $1
    }
  # remove XML prolog:
  } | tail -n +2 | grep -Ev '^(#.*|\s*)$'
}

htd_xproc2()
{
  {
    fnmatch '<* *>' "$2" && {
      # TODO: hack saxon to ignore offline DTD's
      # https://www.scriptorium.com/2009/09/ignoring-doctype-in-xsl-transforms-using-saxon-9b/
      saxon - $1 <<EOM
$2
EOM
    } || {
      test -e "$1" || error "no file for saxon: '$1'" 1
      saxon -dtd "$1" "$2" || return $?
    }
  # remove XML prolog:
  } | cut -c39-
}

htd_relative_path()
{
  cwd=$PWD
  test -e "$1" && {
    x_re "${1}" '\/.*' && {
      error "TODO make rel"
    }
    x_re "${1}" '[^\/].*' && {
      x_re "${1}" '((\.\/)|(\.\.)).*' && {
        relpath="${1: 2}"
      } || {
        relpath="$1"
      }
      return 0
    }
  }
  return 1
}


req_htdir()
{
  test -n "$HTDIR" -a -d "$HTDIR" || return 1
}



htd_report()
{
  # leave htd_report_result to "highest" set value (where 1 is highest)
  htd_report_result=0

  while test $# -gt 0
  do
    case "$1" in

      passed )
          test $passed_count -gt 0 \
            && std_info "Passed ($passed_count): $passed_abbrev"
        ;;

      skipped )
          test $skipped_count -gt 0 \
            && {
              note "Skipped ($skipped_count): $skipped_abbrev"
              test $htd_report_result -eq 0 -o $htd_report_result -gt 4 \
                && htd_report_result=4
            }
        ;;

      error )
          test $error_count -gt 0 \
            && {
              error "Errors ($error_count): $error_abbrev"
              test $htd_report_result -eq 0 -o $htd_report_result -gt 2 \
                && htd_report_result=2
            }
        ;;

      failed )
          test $failed_count -gt 0 \
            && {
              warn "Failed ($failed_count): $failed_abbrev"
              test $htd_report_result -eq 0 -o $htd_report_result -gt 3 \
                && htd_report_result=3
            }
        ;;

      * )
          error "Unknown $base report '$1'" 1
        ;;

    esac
    shift
  done

  return $htd_report_result
}

htd_passed()
{
  test -n "$passed" || error htd-passed-file 1
  stderr ok "$1"
  echo "$1" >>$passed
}


htd_doc_ctime()
{
  grep -i '^:Created:\ [0-9:-]*$' $1 | awk '{print $2}'
}

htd_doc_mtime()
{
  grep -i '^:Updated:\ [0-9:-]*$' $1 | awk '{print $2}'
}


htd_output_format_q()
{
  test -z "$q" || return
  test -n "$of" || error "of env" 1
  test -z "$out_f" -o -n "$f" || error "f env" 1
  case "$out_fmt" in
    list ) test -n "$out_f" && q=0.9 || q=0.5 ;;
    csv | tab )
        test -n "$out_f" && q=0.9 || q=0.5
      ;;
    json ) q=1.0 ;;
    yaml ) q=1.2 ;;
    txt | rst ) q=1.1 ;;
  esac
}

# [remove-swap] vim-swap <file>
vim_swap()
{
  local swp="$(dirname "$1")/.$(basename "$1").swp"
  test ! -e "$swp" || {
    trueish "$remove_swap" && rm $swp || return 1
  }
}


# Set remote/url env for arguments.
# Remote names with periods ('.') are interpreted as
# <hostname>.<remote-id>, and their URL's as paths on those remotes.
# For those on the local host, check if the URL is local path
# and retun 1, otherwise add the hostname to the path, and
# remove the hostname from the remote-name to use.
htd_repository_url() # Remote Url
{
  local remote_hostinfo= remote_dir= remote_id= domain=

  std_info "Getting local references for repo '$1' with URL '$2'"

  fnmatch "*.*" "$1" && {
      remote_id="$(echo $1 | cut -f1 -d'.')"
      remote="$(echo $1 | cut -f2- -d'.')"
    }

  test -n "$remote_id" || {
    test ! -e $UCONF/etc/git/remotes/$remote.sh || remote_id=$remote
  }
  test -z "$remote_id" || {
    . $UCONF/etc/git/remotes/$remote_id.sh
  }
  test -n "$domain" || domain=$remote_id

  test "$hostname" = "$domain" && {

    # Use local access for path
    test -e "$2" || return 1

    # Cancel if repo is local checkout (and expand '~')
    pwd_="$( cd "$2" && pwd -P 2>/dev/null || true)"
    test -e "$2" -a \( \
        "$pwd_" = "$(pwd -P)/.git" -o \
        "$pwd_" = "$(pwd -P)" \
      \) && return 1

    url="$2"

  } || {

    #{ test -e $UCONF/etc/git/remotes/$domain.sh ||
    #  fnmatch "/*" "$2" || fnmatch "~/*" "$2"
    #} || return
    #url="$domain:$2"

    # No namespacing in remote name,
    # prefix remote Id if not local
    test -n "$remote_id" && {
      { fnmatch "*:*" "$2" || test "$remote" = "$hostname"
      } || {
        test -n "$remote_hostinfo" || remote_hostinfo=$remote
        url="$remote_hostinfo:$2"
      }
    } || {
      url="$2"
    }
  }

  # Remove .$scm and .../.$scm suffix
  test -z "$scm" || {
    fnmatch "*/.$scm" "$url" && {
      url="$(echo "$url" | cut -c1-$(( ${#url} - 5 )) )"
    } || {
      fnmatch "*.$scm" "$url" && {
        url="$(echo "$url" | cut -c1-$(( ${#url} - 4 )) )"
      }
    }
  }
}


# Update stats file, append entry to log and set as most current value
htd_ws_stats_update()
{
  local id=_$($gdate +%Y%m%dT%H%M%S%N)
  test -n "$ws_stats" || ws_stats=$workspace/.cllct/stats.yml
  test -s "$ws_stats" || error "Missing '$ws_stats' doc" 1
      # jsotk update requires prefixes to exist. Must create index before
      # updating.
  { cat <<EOM
stats:
  $prefix:
    $1:
      log:
      - &$id $2
      last: *$id
EOM
  } | {
    trueish "$dump" && cat - || jsotk.py update $ws_stats - \
        -Iyaml \
        --list-union \
        --clear-paths='["stats","'"$prefix"'","'"$1"'","last"]'
  }
  # NOTE: the way jsotk deep-update/union and ruamel.yaml aliases work it
  # does not update the log properly by union. Unless we clear the reference
  # first, before it overwrites both last key and log item at once. See jsotk
  # update tests.
}

htd_ws_stat_init()
{
  test -n "$ws_stats" || ws_stats=$workspace/.cllct/stats.yml
  test -s "$ws_stats" || echo "stats: {}" >$ws_stats
  {
    printf -- "stats:\n"
    while read prefix
    do
        printf -- "  $prefix:\n"
        printf -- "    $1: $2\n"
    done
  } | {
    trueish "$dump" && cat - || jsotk.py merge-one $ws_stats - $ws_stats \
    -Iyaml -Oyaml --pretty
  }
}

htd_ws_stat_update()
{
  test -n "$ws_stats" || ws_stats=$workspace/.cllct/stats.yml
  test -s "$ws_stats" || error "Missing '$ws_stats' doc" 1
  {
    printf -- "stats:\n"
    while read prefix stat
    do
      printf -- "  $prefix:\n"
      printf -- "    $1: \"$stat\"\n"
    done
  } | {
    trueish "$dump" && cat - || jsotk.py merge-one $ws_stats - $ws_stats \
    -Iyaml -Oyaml --pretty
  }
}

get_jsonfile()
{
  fnmatch "*.json" "$1" && {
    echo "$1"; return
  }

  { fnmatch "*.yaml" "$1" || fnmatch "*.yml" "$1"
  } && {
    set -- "$1" "$(pathname "$1" .yml .yaml).json"
    test "$2" -nt "$1" || jsotk yaml2json --pretty "$@"
    echo "$2"; return
  }
}

# Set mode to 0 to inverse action or 1 for normal
htd_filter() # [type_= expr_= mode_= ] [Path...]
{
  act_() {
    test $mode_ = 1 && {
      # Filter: echo positive matches
      echo "$S"
    } || {
      not_trueish "$DEBUG" || error "failed at '$type_' '$expr_' '$S'"
    }
  }
  no_act_() {
    test $mode_ = 0 && {
      # Filter-out mode: echo negative matches
      echo "$S"
    } || {
      not_trueish "$DEBUG" || error "failed at '$type_' '$expr_' '$S'"
    }
  }
  act=act_ no_act=no_act_ foreach_do "$@"
}

# Given ID, look for shell script with function
htd_function_comment() # Func-Name [ Script-Path ]
{
  upper= mkvid "$1" ; shift ; set -- "$vid" "$@"
  test -n "$2" || {
    # TODO: use SCRIPTPATH?
    #set -- "$1" "$(first_match=1 functions_find "$1" $scriptpath/*.sh)"
    set -- "$1" "$(first_match=1 functions_find "$1" $(git ls-files | grep '\.sh$'))"
  }
  file="$2"
  test -n "$2" || { error "No shell scripts for '$1'" ; return 1; }
  func_comment "$@" || return $?
}

htd_function_help()
{
  test -n "$file" || return 1
  grep "^$vid " "$file"
  decl_comment=$( grep "^$vid()" "$file" | sed 's/^[A-Za-z0-9_]*()[\ \{\#]*//' )
  echo
  test -n "$decl_comment" && {
      echo "$1( $decl_comment ) # found on $file:$grep_line"
  } ||
      echo "$1() # found on $file:$grep_line"
}

# Find paths, follow symlinks below, print relative paths.
htd_find() # Dir [ Namespec ]
{
  test -n "${find_match-}" || local find_match="-type f -o -type l"
  test -n "${find_ignores-}" || local find_ignores="-false $(ignores_find $IGNORE_GLOBFILE)"
  test -n "$1" || set -- "$PWD"
  match_grep_pattern_test "$1"
  {
    test -z "$2" \
      && eval "find -L $1 $find_ignores -o \( $find_match \) -print" \
      || eval "find -L $1 $find_ignores -o \( $2 \) -a \( $find_match \) -print"
  } | grep -v '^'$p_'$' \
    | sed 's/'$p_'\///'
}

# Expand paths from arguments or stdin, echos existing paths at dir=$CWD.
# Set expand-dir=false to exclude absolute working dir or given directory from
# echoed expansion.
htd_expand()
{
  test -n "$dir" || dir=$CWD

  # Normal behaviour is to include dir in expansion, set trueish to give names only
  test -n "$expand_dir" || expand_dir=1
  trueish "$expand_dir" && expand_dir=1 || expand_dir=0

  {
    # First step, foreach arguments or stdin lines
    test -n "$1" -a "$1" != "-" && {
      while test $# -gt 0
      do
          echo "$1"
          shift
      done
    } || cat -
  } | {

    local cwd= ; test "$expand_dir" = "1" || cd $dir

    # Do echo as path, given name or expand paths from dir/arg
    while read arg
    do
      test "$expand_dir" = "1" && {
        for path in $dir/$arg
          do
            echo "$path"
          done
      } || {
        for name in $arg
        do
          echo "$name"
        done
      }
    done
    test "$expand_dir" = "1" || cd $cwd
  }
}


htd_edit_main()
{
  local evoke= files="$(cat $arguments)" fn=
  locate_name || return 1
  vim_swap "$(realpath "$fn")" || error "swap file exists for '$fn'" 2
  files="$files $fn $(columnize=false htd__ls_main_files | lines_to_words )"
  # XXX:
  #libs_n_docs="\
  #  $(dirname $fn)/$(basename "$fn").lib.sh \
  #  $(dirname $fn)/$(basename "$fn").rst \
  #  $(dirname $fn)/*.lib.sh"
  test "$EDITOR" = "vim" || error "unsupported '$EDITOR'" 1
  evoke="vim "

  # Search in first pane
  test -z "$search" || evoke="$evoke -c \"/$search\""

  # Two vertical panes (O2), with additional h-split in the right
  #evoke="$evoke -O2
  evoke="$evoke \
    -c :vsplit \
    -c \":wincmd l\" \
    -c \"normal gg $\" \
    -c :split \
    -c \"wincmd j\" \
    -c \"normal G $\" \
    -c \"wincmd h\""
  printf "$(tput bold)$(tput setaf 0)$evoke $files$(tput sgr0)\n"
  bash -c "$evoke $files"
}

htd_edit_note()
{
  test -n "$1" || error "ID expected" 1
  test -n "$2" || error "tags expected" 1
  test -z "$3" || error "surplus arguments" 1
  req_dir_env HTDIR

  id="$(printf "$1" | tr -cs 'A-Za-z0-9' '-')"
  #id="$(echo "$1" | sed 's/[^A-Za-z0-9]*/-/g')"

  case " $2 " in *" nl "* | *" en "* ) ;;
    * ) set -- "$1" "$2 en" ;; esac
  fnmatch "* rst *" " $2 " || set -- "$1" "$2 rst"
  ext="$(printf "$(echo $2)" | tr -cs 'A-Za-z0-9_-' '.')"

  note=$HTDIR/note/$id.$ext
  htd_rst_doc_create_update $note "$1" created default-rst
  htd_edit_and_update $note
}

gitrepos()
{
  test -n "$repos" && { test -z "$*" || error no-args-expected 41
    echo $repos | words_to_lines
    return
  }

  test -n "$dir" || dir=/srv/scm-git-local/$NS_NAME
  test -z "$*" -a "t" != "$stdio_0_type" && set -- -
  test -n "$*" || set -- *.git

  htd_expand "$@"
}


# Given context or path with context, load ctx lib and run action.
htd_wf_ctx_sub () # Flow-Id Tag-Refs...
{
  local flow=${1:?} fid; upper=0 mkvid "$1" ; shift ; fid="$vid"
  test -n "${ctx_base-}" || local ctx_base=${base}_ctx__

  $LOG info "htd-workflow" "Preparing to run action for context(s)" "$ctx_base:$flow:$*"
  htd_current_context "$@" || return $?

  sh_fun ${ctx_base}${primctx_id}__${fid} && {
    $LOG debug "htd-workflow" "Existing primary env" "ctx=$ctx"
  } || {
    $LOG info "htd-workflow" "No hook for primary, loading" "$primctx Id:${primctx_id} #${primctx_sid}"
    lib_require ctx-${primctx_sid} || return

    # XXX: defer to init hook?
    func_exists ctx_${primctx_id}_lib__init && {
      $LOG info "htd-workflow" "" "ctx-${primctx_id}-init $*"
      ctx_${primctx_sid}_lib__init "$@" || {
        $LOG error "" "context lib init failed for '$primctx_sid'" "$*" 1
        return 1
      }
    }
  }
  #try_context_actions current std base
  #$LOG info "htd-workflow" "Running '${flow}'" "${ctx_base}${primctx_sid}__${flow} $*"
  #${ctx_base}${primctx_sid}__${flow} "$@" &&
#      $LOG note "htd-workflow" "Finished '${flow}'" "${ctx_base}${primctx_sid}__${flow} $*"

  CTX_PREF=$ctx_base context_uc_cmd_seq $fid -- "$@"
}


# Get primary context...
htd_current_context ()
{
  test -n "${1-}" && {
    test -e "$1" && {
      context_exists_tag "$1" && {
        context_tag_env "$1" &&
        contexttab_init @$tag_id $rest
        return $?
      }
      context_exists_subtagi "$1" && {
        context_subtag_env "$1" &&
        contexttab_init @$tag_id $rest
        return $?
      }
    }
    fnmatch "@*" "$1" && {
      context_exists_tag $(echo "$1" | cut -c2-) || {
        $LOG error "" "No such tag" "$1" $?
        return $?
      }
      contexttab_init "$1"
      return $?
    }
    fnmatch "+*" "$1" && {
      htd_project_exists $(echo "$1" | cut -c2-) || {
        $LOG error "" "No such project" "$1" $?
        return $?
      }
      test "$package_id" = "$project_id" || error TODO 1
      # TODO: get primctx for other package
      #( cd "...$1" && htd context ... )
      contexttab_init "$package_lists_contexts_default"
      return $?
    }
  }
  contexttab_init
}


htd_modeline ()
{
  file_modeline "$@"
}

# Id: script-mpe/0.0.4-dev ht.sh
