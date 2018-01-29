#!/bin/sh


# Setup temp-file index for shell env profile, created from pathnames-table
req_prefix_names_index() # Pathnames-Table
{
  test -n "$1" || set -- pathnames.tab
  test -n "$index" || export index=$(setup_tmpf .prefix-names-index)
  test -s "$index" -a "$index" -nt "$UCONFDIR/$1" || {
    htd_topic_names_index "$1" > $index
  }
}


# List prefix varnames
htd_prefix_names()
{
  test -n "$index" || local index=
  test -s "$index" || req_prefix_names_index

  read_nix_style_file $index | awk '{print $2}' | uniq
}


# Return prefix:<localpath> after scanning paths-topic-names
htd_prefix() # Local-Path
{
  test -n "$index" || local index=
  test -s "$index" || req_prefix_names_index

  # Set abs-path
  fnmatch "/*" "$1" || set -- "$(pwd -P)/$1"
  # Add '/' for dir path
  fnmatch "*/" "$1" || { test -e "$1" -a -d "$1" && set -- "$1/" ; }

  local path="$1"
  # Find deepest named prefix
  while true
  do
    # Travel to root, break on match
    grep -qF "$1 " "$index" && break || set -- "$(dirname "$1")/"
    test "$1" != "//" && continue || set -- /
    break
  done
  # Get first name for path
  local prefix_name="$( grep -F "$1 " $index | head -n 1 | awk '{print $2}' )"
  fnmatch "*/" "$1" || set -- "$1/"
  # offset on furter for `cut`
  set -- "$1+"
  local v="$( echo "$path" | cut -c${#1}- )"
  test -n "$v" || {
    test "$prefix_name" == ROOT && v=/
  }
  trueish "$htd_path" &&
      echo "$path $prefix_name:$v" ||
      echo "$prefix_name:$v"
}


# Return prefix:<localpath> after scanning paths-topic-names
htd_prefixes() # (Local-Path..|-)
{
  test -n "$index" || local index=
  test -s "$index" || req_prefix_names_index

  { test "$1" = "-" && {
    while read p ; do echo "$p" ; done
  } || {
    for p in "$@"; do echo "$p" ; done
  } ; } | while read p ; do

    htd_prefix "$p"
  done
}

# Same as htd-prefixes but prefix with original apth
htd_path_prefixes()
{
  htd_path=1 htd_prefixes "$@"
}

# Expand <prefix>:<local-path> to abs
htd_prefix_expand() # Prefix
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
htd_path_prefix_names()
{
  test -n "$index" || local index=
  req_prefix_names_index
  test -s "$index"
  cat $index | sed 's/^[^\#]/'$(hostname -s)':&/g'
  note "OK, $(count_lines "$index") rules"
}


htd_update_prefixes_redis()
{
  local sd_be=redis

  # Update two redis keys; one with all prefix names, the other with
  # prefix localpaths

  htd_path=1 htd_act=1 \
      htd__prefixes current | while IFS=' :' read act path pref lp
  do
    test -n "$pref" -a -n "$lp" || continue

    test $(statusdir.sh be sismember htd:prefixes:names "$pref") -eq 1 && {

      test "$act" = "+" && {
        stderr debug "Present '$pref' as pref"
      } || {
        test $(statusdir.sh be srem htd:prefixes:names "$pref") -eq 1 &&
          stderr note "Removed '$pref' as pref" ||
          stderr warn "Failed removing '$pref' as pref ($?)"
      }
    } || {

      test "$act" = "-" && {
        stderr debug "Not present '$pref' as pref"
      } || {
        test $(statusdir.sh be sadd htd:prefixes:names "$pref") -eq 1 &&
          stderr ok "Added '$pref' to prefixes" ||
          error "Adding '$pref' to prefixes " 1
      }
    }

    test $(statusdir.sh be sismember htd:prefix:$pref:paths "$lp") -eq 1 && {

      test "$act" = "+" && {
        stderr debug "Present '$lp' in '$pref' pref"
      } || {
        test $(statusdir.sh be srem htd:pref:$pref:paths "$lp") -eq 1 &&
          stderr note "Removed '$lp' from '$pref' pref" ||
          stderr warn "Failed removing '$lp' in '$pref' pref ($?)"
      }
    } || {

      test "$act" = "-" && {
        stderr debug "Not present '$lp' in '$pref' pref"
      } || {

        test $(statusdir.sh be sadd htd:pref:$pref:paths "$lp") -eq 1 &&
          stderr ok "Added '$lp' to pref '$pref'" ||
          error "Adding '$lp' to pref '$pref' " 1
      }
    }
  done
}

htd_update_prefixes_couch()
{
  export COUCH_DB=htd
  sd_be=couchdb_sh

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
            error "Sumitting to couchdb"
            return 1
          }

    #COUCH_DB=htd sd_be=couchdb_sh \
    #  statusdir.sh set ""
}

htd_update_prefixes()
{
  htd_update_prefixes_redis

  htd_update_prefixes_couch
}



htd_list_prefixes()
{
  test -n "$out_fmt" || out_fmt=plain
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
      test -n "$(echo $prefix)" &&
        local val="$(eval echo \"\$$prefix\")" ||
        local prefix=ROOT val=/
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
    case "$out_fmt" in json ) printf "]" ;; esac
  ) | {
    test "$out_fmt" = "json" && sed 's/,\]/\]/g' || cat -
  }
}
