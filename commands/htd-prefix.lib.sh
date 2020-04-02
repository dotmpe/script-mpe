## Prefixes: named paths, or aliases for base paths


htd_prefix_lib_load()
{
  # 2016-09-18
  ns_tab=$UCONF/namespace/$hostname.tab
}

htd_man_1__prefix='Alias for `prefixes`. See also dev notes.'

htd_man_1__prefixes='Manage local prefix table and index, or query cache.

  (op|open-files)
    Default command. Pipe htd current-cwd to htd prefixes names.
    Set htd_path=1 to get full paths with prefix/localname pairs outputted in
    one line.

Read from table
  list
    List prefix varnames from table.
  table | raw-table
    Print user or default prefix-name lookup table
  table-id
    Print table filename

Lookup with table
  name Path-Name
    Resolve to real, absolute path and echo <prefix>:<localpath> by scanning
    prefix index.
  names (Path-Names..|-)
    Call name for each line or argument.
  pairs (Path-Names..|-)
    Get both path and name for each line or argument.
  expand (Prefix-Paths..|-)
    Expand <prefix>:<local-path> back to to absolute path.
  op
    Feed Htd-current-paths through htd-prefixes-names

Cache
  cache
    List cached prefixes and paths beneath them.
  update [TTL=60min [<persist=false>]]
    Update cache, read below.
  current
    List but dont update, this is essentially the same as htd-prefixes-op but
    tailored for htd-update-prefixes.

Other
  check
    TODO htd prefixes check ..

See prefix.rst for design and use-cases.

# Cache
Cache has two parts. An in-memory index, for tracking current prefixes,
and the local paths beneath prefixes. And secondary a persisted part, where a
cumulative tree of all prefixes/paths for a certain period is stored. And where
individual cards are kept per path, with timestamps.

The in-memory parts are updated every run of `update`.
Paths are kept in memory for TTL seconds after they closed, to allow recalling
them during that time.

If there is a change, the persisted document is not updated. Only until some
path TTL expires and is dropped from the index is the persisted document updated
automatically. Otherwise, a persist to secondary storage is only requested by
invocation argument.

Updating the first cache requires checking and possibly changing two lists.
For the secondary, several JSON documents are created: one with the entire tree
and current time, and if needed one for each path, setting a new ctime.
This setup prevents conflicts in distributed stores, but it leaves the task of
cleaning up old trees and ctimes documents.

'
htd__prefixes()
{
  test -n "$index" || local index=
  test -s "$index" || prefix_require_names_index || return

  test -n "$1" || set -- op
  case "$1" in

    # Read from table
    info|table-id ) shift ;  echo $UCONF/$pathnames ; test -e "$pathnames" || return $? ;;
    raw-table ) shift ;      cat $UCONF/$pathnames || return $? ;;
    tab|table )              prefix_tab || return $? ;;
    list )                   prefix_names || return $? ;;

    # Lookup with table
    name ) shift ;           prefix_resolve "$1" || return $? ;;
    names ) shift ;          prefix_resolve_all "$@" || return $? ;;
    pairs ) shift ;          prefix_resolve_all_pairs "$@" || return $? ;;
    expand ) shift ;         prefix_expand "$@" || return $? ;;

    # Update/fetch from cache
    cache )                  htd_list_prefixes || return $? ;;
    update )                 htd_update_prefixes || return $? ;;
    current )
        htd__current_paths | prefix_resolve_all_pairs - |
          while IFS=' :' read path prefix localpath
        do
          trueish "$htd_act" && {
            older_than $path $_1HOUR && act='- ' || act='+ '
          }

          trueish "$htd_path" &&
              echo "$act$path" || echo "$act$prefix:$localpath"
        done
      ;;

    op | open-files ) shift
        $LOG note "" "Resolving prefix-names for current-paths"
        htd__current_paths | prefix_resolve_all -
      ;;

    check )
        # Read index and look for env vars
        prefix_names | while read name
        do mkvid "$name"
            #val="${!vid}"
            val="$( eval echo \"\$$vid\" )"
            test -n "$val" || warn "No env for $name"
        done
      ;;

    * ) error "No subcmd $1" ; return 1 ;;
  esac
} # End prefixes

htd_of__prefixes_list='plain text txt rst yaml yml json'

htd_of__prefixes_update='txt rst plain'


# List root IDs
htd__list_local_ns()
{
  test -e "$ns_tab" || warn "No namespace table for $hostname" 1
  fixed_table $ns_tab SID GROUPID| while read vars
  do
    eval local "$vars"
    echo $SID
  done
}

# TODO: List namespaces matching query
htd_spc__ns_names='ns-names [<path>|<localname> [<ns>]]'
htd__ns_names()
{
  test -z "$3" || error "Surplus arguments: $3" 1
  test -e "$ns_tab" || warn "No namespace table for $hostname" 1
  fixed_table "$ns_tab" SID GROUPID | while read vars
  do
    eval local "$vars"
    note "FIXME: $SID eval local var from pathnames.tab"
    continue
    cd $CMD_PATH
    note "In '$ID' ($CMD_PATH)"
    eval $CMD "$1"
    cd $CWD
  done
}

#
