#!/bin/sh

# shellcheck disable=SC2034,SC2154

htd_relative_path()
{
  cwd=$(pwd)
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

  while test -n "$1"
  do
    case "$1" in

      passed )
          test $passed_count -gt 0 \
            && info "Passed ($passed_count): $passed_abbrev"
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

  fnmatch "*.*" "$1" && {
      remote_id="$(echo $1 | cut -f1 -d'.')"
      remote="$(echo $1 | cut -f2- -d'.')"
    }

  test -n "$remote_id" || {
    test ! -e $UCONFDIR/git/remote-dirs/$remote.sh || remote_id=$remote
  }
  test -z "$remote_id" || {
    . $UCONFDIR/git/remote-dirs/$remote_id.sh
  }
  test -n "$domain" || domain=$remote_id

  test "$hostname" = "$domain" && {

    # Use local access for path
    # Cancel if repo is local checkout (and expand '~')
    pwd_="$( { cd "$(bash -c "echo $2")" && pwd -P ; } 2>/dev/null)"
    test -e "$2" -a "$pwd_" = "$(pwd -P)" && return 1
    url="$2"

  } || {

    #{ test -e $UCONFDIR/git/remote-dirs/$domain.sh ||
    #  fnmatch "/*" "$2" || fnmatch "~/*" "$2"
    #} || return
    #url="$domain:$2"

    # No namespacing in remote name,
    # prefix remote-dirs if not local
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
  act=act_ no_act=no_act_ foreach "$@"
}


# Take an REST url and go request
htd_resolve_paged_json() # URL Num-Query Page-query
{
  test -n "$1" -a "$2" -a "$3" || return 100
  local tmpd=/tmp/json page= page_size=
  mkdir -p $tmpd
  page_size=$(eval echo \$$2)
  page=$(eval echo \$$3)
  case "$1" in
    *'?'* ) ;;
    * ) set -- "$1?" "$2" "$3" ;;
  esac
  test -n "$page" || page=1
  while true
  do
    note "Requesting '$1$2=$page_size&$3=$page'..."
    out=$tmpd/page-$page.json
    curl -sSf "$1$2=$page_size&$3=$page" > $out
    json_list_has_objects "$out" || { rm "$out" ; break; }
    page=$(( $page + 1 ))
  done

  test -e "$tmpd/page-1.json" || error "Initial page expected" 1

  count="$( echo $tmpd/page-*.json | count_words )"
  test "$count" = "1" && {
      cat $tmpd/page-1.json
  } || {
      jsotk merge --pretty $tmpd/page-*.json -
      #$tmpd/page-*.json cat $tmpd/merged.json
  }
  rm -rf $tmpd/
}

json_list_has_objects()
{
  jsotk -sq path $out '0' --is-obj || return
  #jq -e '.0' $out >>/dev/null || break
}

# Given ID, look for shell script with function
htd_function_comment() # Func-Name [ Script-Path ]
{
  upper= mkvid "$1" ; shift ; set -- "$vid" "$@"
  test -n "$2" || {
    # TODO: use SCRIPTPATH?
    #set -- "$1" "$(first_match=1 find_functions "$1" $scriptpath/*.sh)"
    set -- "$1" "$(first_match=1 find_functions "$1" $(git ls-files | grep '\.sh$'))"
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
  test -n "$find_match" || find_match="-type f -o -type l"
  test -n "$find_ignores" || find_ignores="-false $(find_ignores $IGNORE_GLOBFILE)"
  test -n "$1" || set -- "$(pwd)"
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

# Get any alias
htd_alias_get()
{
  grep " \<$1\>=" ~/.alias | awk -F '=' '{print $2}'
}

# List aliases (for current script)
htd_alias_list()
{
  grep 'alias \<'"$scriptname"'\>=' ~/.alias |
      sed 's/^.* alias /alias /g' | grep -Ev '^(#.*|\s*)$' | while read -r _a A
  do
    a_id="$(echo "$A" | awk -F '=' '{print $1}')"
    a_shell="$(echo "$A" | awk -F '=' '{print $2}')"
    printf -- "%-18s%s\n" "$a_id" "$a_shell"
  done
}
