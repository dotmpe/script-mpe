#!/bin/sh

htd__env='Print env var names (local or global)

  all | local | global | tmux
    List env+local, local, env or tmux vars.
    Names starting with "_" are filtered out.

  pathnames | paths | pathvars
    Tries to print names, values, or variable declarations where value is a
    lookup path. The values must match ``*/*:*/*``. This may include some URLs.
    Excludes values with only local names, or at least two paths.

  dirnames | dirs | dirvars
    Print names, values, or variable declarations where value is a directory path.

  filenames | files | filevars
    Print names, values, or variable declarations where value is a file path.

  symlinknames | symlinks | symlinkvars
    Print names, values, or variable declarations where value is a symlink path.

  foreach (all|local|global) [FUNC [FMT [OUT]]]
    Print <OUT>names, <OUT>s or <OUT>vars.
    By default prints where value is an existing path.

XXX: Doesnt print tmux env. and whatabout launchctl
'

htd__env()
{
  test -n "$1" || set -- all
  case "$1" in

    foreach )
        test -n "$4" -a -n "$5" || set -- "$1" "$2" "$3" vars
        test -n "$2" || set -- "$1" all "$3" "$4" "$5"
        test -n "$3" || {
            _f() { test -e "$2" ; }
            set -- "$1" "$2" "_f" "$4" "$5"
        }
        htd__env $2 | while read varname
        do
            V="${!varname}" ; $3 "$varname" "$V" || continue
            case "$4" in
                ${5}names ) echo "$varname" ;;
                ${5}s ) echo "$V" ;;
                ${5}vars ) echo "$varname=$V" ;;
            esac
        done
          ;;

    pathnames | paths | pathvars )
        _f(){ case "$2" in *[/]*":"*[/]* ) ;; * ) return 1 ;; esac; }
        htd__env foreach "$2" _f "$1" path
      ;;

    dirnames | dirs | dirvars )
        _f() { test -d "$2" ; }
        htd__env foreach "$2" _f "$1" dir
      ;;

    filenames | files | filevars )
        _f() { test -f "$2" ; }
        htd__env foreach "$2" _f "$1" file
      ;;

    symlinknames | symlinks | symlinkvars )
        _f() { test -L "$3" ; }
        htd__env foreach "$2" _f "$1" symlink
      ;;

    all )
        { env && local; } | sed 's/=.*$//' | grep -v '^_$' | sort -u
      ;;
    global )
        env | sed 's/=.*$//' | grep -v '^_$' | sort -u
      ;;
    local )
        local | sed 's/=.*$//' | grep -v '^_$' | sort -u
      ;;

    lookup-list ) shift ;
        lookup_path_list "$@"
      ;;

    lookup ) shift ;
        lookup_path "$@"
      ;;

    lookup-shadows ) shift ;
        lookup_path_shadows "$@"
      ;;

    #host ) # XXX: tmux, launch/system/init daemon?
    #  ;;
    tmux ) # XXX: cant resolve the from shell
        htx__tmux show local
      ;;
    #* ) # XXX: schemes looking at ENV, ENV_NAME
    #  ;;
  esac
}

env__help()
{
  std_help env
}

htd__env_info()
{
  log "Script:                '$scriptname'"
  log "User Config Dir:       '$UCONF' [UCONF]"
  log "User Public HTML Dir:  '$HTDIR' [HTDIR]"
  log "Project ID:            '$PROJECT' [PROJECT]"
  log "Minimum filesize:      '$(( $MIN_SIZE / 1024 ))'"
  log "Editor:                '$EDITOR' [EDITOR]"
  log "Default GIT remote:    '$HTD_GIT_REMOTE' [HTD_GIT_REMOTE]"
  log "Ignored paths:         '$IGNORE_GLOBFILE' [IGNORE_GLOBFILE]"
}


htd__show()
{
  show_inner() { eval echo \"\$$1\"; }
  p= s= act=show_inner foreach_do "$@"
}


htd__home()
{
  htd__show HTDIR
}

htd__whoami()
{
  note "Host: $(whoami) (${OS_NAME:-${OS_UNAME}})"
  note "GIT: $(git config --get user.name)"
}

#
