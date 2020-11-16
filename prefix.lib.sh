#!/bin/sh

## Named basedirs

prefix_lib_load()
{
  test -n "${pathnames-}" || pathnames=user/pathnames.tab
}

prefix_lib_init()
{
  lib_assert statusdir || return
  test -n "${UCONF-}" || UCONF=$HOME/.conf
  test -n "${BASEDIR_TAB-}" || BASEDIR_TAB=${STATUSDIR_ROOT}index/basedirs.tab
}

prefix_init()
{
  test -e "$BASEDIR_TAB" || {
    mkdir -p "$(dirname "$BASEDIR_TAB")"
    touch "$BASEDIR_TAB" || return $?
  }
}

# Build a table of paths to env-varnames, to rebuild/shorten paths using variable names
prefix_pathnames_tab()
{
  test -n "${1-}" || set -- "$UCONF/$pathnames" "${2-}"

  { test -n "$1" -a -s "$1" && {

    # Store temporary sh-script wrapping pathnames.tab template
    local tmpsh=$(setup_tmpf .topic-names-index.sh)
    { echo 'cat <<EOM'
      read_nix_style_file "$1"
      echo 'EOM'
    } > $tmpsh
    $SHELL $tmpsh
    rm $tmpsh
  } || { cat <<EOM
/ ROOT
$HOME/ HOME
\$(test -e "\$UCONF" && echo \$UCONF/ UCONF)
EOM
    }
  } | uniq
}

# Setup temp-file index for shell env profile, created from pathnames-table
prefix_require_names_index() # Pathnames-Table
{
  test -n "${1:-}" || set -- "$UCONF/$pathnames" "${2:-}"
  test -n "${2:-}" || set -- "$1" "$BASEDIR_TAB"
  test $# -eq 2 || return
  test -f "$1" || return

  test -n "${index-}" || index=$2
  test -s "$index" -a "$index" -nt "$1" || {
    std_info "Building $index from '$1'"
    #{ prefix_pathnames_tab "$1" || return $? ; }> "$index"
    prefix_pathnames_tab "$1" > "$index"
  }
}

# List prefix varnames
prefix_names()
{
  # Build from tpl and cat file
  test -n "${index-}" || local index=
  test -s "$index" || prefix_require_names_index || return
  read_nix_style_file $index | awk '{print $2}' | uniq
}


# Return prefix:<localpath>
prefix_resolve() # Local-Path
{
  test $# -eq 1 -a -n "${1-}" || return
  test -n "${index-}" || local index=
  test -s "$index" || prefix_require_names_index || return

  # Set abs-path
  fnmatch "/*" "$1" || set -- "$(pwd -P)/$1"
  # Add '/' for dir path
  fnmatch "*/" "$1" || { test -e "$1" -a -d "$1" && set -- "$1/" ; }
  local path="$1" p=
  # Find deepest named prefix
  while true
  do
    p="^$(match_grep "$1")\ "
    # Travel to root, break on match
    grep -q "$p" "$index" && break || set -- "$(dirname "$1")/"
    test "$1" != "//" && continue || set -- /
    break
  done
  # Get first name for path
  p="^$(match_grep "$1")\ "
  local prefix_name="$( grep "$p" $index | head -n 1 | awk '{print $2}' )"
  fnmatch "*/" "$1" || set -- "$1/"
  # offset on furter for `cut`
  set -- "$1+"
  local v="$( echo "$path" | cut -c${#1}- )"
  test -n "$v" || {
    test "$prefix_name" == ROOT && v=/
  }
  # Prefix with input path or output only result
  test ${prefix_paths:-0} -eq 1 &&
      echo "$path $prefix_name:$v" ||
      echo "$prefix_name:$v"
}

# Echo each prefix:<localpath> after scanning paths-topic-names
prefix_resolve_all() # (Local-Path..|-)
{
  test -n "${index-}" || local index=
  test -s "$index" || prefix_require_names_index || return

  test "$1" = "-" && {
    while read p ; do prefix_resolve "$p" ; done
  } || {
    for p in "$@"; do prefix_resolve "$p" ; done
  }
}

# Same as htd-prefixes but prefix with original path
prefix_resolve_all_pairs()
{
  prefix_paths=1 prefix_resolve_all "$@"
}

# Expand <prefix>:<local-path> to abs
prefix_expand() # Prefix
{
  test -n "$1" || error "Prefix-Path-Arg expected" 1
  {
    test "$1" = "-" && { cat - ; shift ; }
    for a in "$@" ; do echo "$a" ; done
  } | tr ':' ' ' | while read prefix lname
  do
    echo "$(eval echo \"\$$prefix\")/$lname"
  done
}

# Print user or default prefix-name lookup table
prefix_tab()
{
  test -n "${index-}" || local index=
  prefix_require_names_index || return
  test -s "$index" || return
  cat $index | sed 's/^[^\#]/'$(hostname -s)':&/g'
  note "OK, $(count_lines "$index") rules"
}


htd_update_prefixes_redis()
{
  local sd_be=redis

  # Update two redis keys; one with all prefix names,
  # the other with localpaths per prefix
  htd_path=1 htd_act=1 htd__prefixes current | while IFS=' :' read act path pref lp
  do
    test -n "$pref" -a -n "$lp" || continue

    test $(statusdir.sh has htd:prefixes:names "$pref") -eq 1 && {

      test "$act" = "+" && {
        stderr debug "Present '$pref' as pref"
      } || {
        test $(statusdir.sh rem htd:prefixes:names "$pref") -eq 1 &&
          stderr note "Removed '$pref' as pref" ||
          stderr warn "Failed removing '$pref' as pref ($?)"
      }
    } || {

      test "$act" = "-" && {
        stderr debug "Not present '$pref' as pref"
      } || {
        test $(statusdir.sh add htd:prefixes:names "$pref") -eq 1 &&
          stderr ok "Added '$pref' to prefixes" ||
          error "Adding '$pref' to prefixes " 1
      }
    }

    test $(statusdir.sh has htd:prefix:$pref:paths "$lp") -eq 1 && {

      test "$act" = "+" && {
        stderr debug "Present '$lp' in '$pref' pref"
      } || {
        test $(statusdir.sh rem htd:pref:$pref:paths "$lp") -eq 1 &&
          stderr note "Removed '$lp' from '$pref' pref" ||
          stderr warn "Failed removing '$lp' in '$pref' pref ($?)"
      }
    } || {

      test "$act" = "-" && {
        stderr debug "Not present '$lp' in '$pref' pref"
      } || {

        test $(statusdir.sh add htd:pref:$pref:paths "$lp") -eq 1 &&
          stderr ok "Added '$lp' to pref '$pref'" ||
          error "Adding '$lp' to pref '$pref' " 1
      }
    }
  done
}

htd_update_prefixes_couch()
{
  export COUCH_DB=htd sd_be=couchdb_sh

  # FIXME: create a global doc with hostname info at couchdb
  statusdir.sh del htd:$hostname:prefixes || true

  {
    printf -- "_id: 'htd:$hostname:prefixes'\n"
    #printf -- "fields: type: ""'\n"
    printf -- "type: 'application/vnd.wtwta.htd.prefixes'\n"
    printf -- "prefixes:\n"
    sd_be=redis out_fmt=yml htd_list_prefixes
  } |
      jsotk yaml2json |
        curl -X POST -sSf $COUCH_URL/$COUCH_DB \
          -H "Content-Type: application/json" \
          -d @- &&
            note "Submitted to couchdb" || {
                error "Submitting to couchdb"
                return 1
              }
}

htd_update_prefixes()
{
  htd_update_prefixes_redis
  #htd_update_prefixes_couch
}

# XXX: List formatted prefixes from statusdir backend?
htd_list_prefixes()
{
  case "$out_fmt" in plain|text|txt|rst|restructuredtext|yaml|yml|json) ;;
      *) out_fmt=plain ;; esac
  test -n "$sd_be" || sd_be=redis
  note "htd prefixes backend: $sd_be"
  (
    case "$out_fmt" in json ) printf "[" ;; esac
    case "$sd_be" in
      redis ) statusdir.sh be smembers htd:prefixes:names ;;
      couchdb_sh ) warn todo 1 ;;
      * ) warn "not supported statusdir backend '$sd_be' " 1 ;;
    esac | while read prefix
    do
      test -n "$(echo $prefix)" && {
          val="$(eval echo \"\$$prefix\")" ||
          val="$(eval echo \"\$${prefix}DIR\")"
      } || continue

      case "$out_fmt" in
        plain|text|txt )
            test -n "$val" &&
              printf -- "$prefix <$val>\n" || printf -- "$prefix\n"
          ;;
        rst|restructuredtext )
            test -n "$val" &&
              printf -- "\`$prefix <$val>\`_\n" || printf -- "$prefix\n"
          ;;
        yaml|yml )
            test -n "$val" &&
              printf -- "- prefix: $prefix\n  value: $val\n  paths:" ||
              printf -- "- prefix: $prefix\n  paths:"
          ;;
        json ) test -z "$val" &&
            printf "{ \"name\": \"$prefix\", \"subs\": [" ||
            printf "{ \"name\": \"$prefix\", \"path\": \"$val\", \"subs\": ["
          ;;
        * ) warn "unsupported output-format '$out_fmt' " 1 ;;
      esac

      case "$sd_be" in
        redis ) statusdir.sh be smembers htd:prefix:$prefix:paths ;;
        * ) warn "not supported statusdir backend '$sd_be' " 1 ;;
      esac | while read localpath
      do
        test -n "$localpath" || continue
        case "$out_fmt" in
          plain|text|txt|rst )
              test -z "$localpath" &&
                printf -- "  ..\n" ||
                printf -- "  - $localpath\n"
            ;;
          yaml|yml )
              test -z "$localpath" &&
                printf -- " []" ||
                printf -- "\n  - '$localpath'"
            ;;
          json ) printf "\"$localpath\"," ;;
        esac
      done
      case "$out_fmt" in yaml|yml|plain|text|txt|rst ) echo ;;
        json ) printf "]}," ;;
      esac
    done
    case "$out_fmt" in json ) printf -- "]" ;; esac
  ) | {
    test "$out_fmt" = "json" && sed 's/,\]/\]/g' || cat -
  }
}
