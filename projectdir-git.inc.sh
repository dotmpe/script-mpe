
pd_register git init check sync test


pd_init__git_autoconfig()
{
  return 0
  # TODO: pd run git:clean
  test -d .git && echo :git:hooks
}

pd_check__git_autoconfig()
{
  test -d .git && echo :git:status
  return 0
}

pd_test__git_autoconfig()
{
  test -d .git && echo :git:status
  return 0
  # TODO: pd run git:clean
  test -d .git && echo :git:clean
}


pd_flags__git_status=i
pd__git_status()
{
  local R=0
  test -n "$1" || set -- .
  ( cd "$1"; vc__regenerate; )
  # TODO: cleanup vc internals
  pd_clean "$1" || R=$?
  case "$R" in

    0|"" )
        std_info "OK $(vc__stat "$1")"
      ;;

    1 )
        warn "Dirty: $(vc__stat "$1")"
        return 1
      ;;

    2 )
        cruft_lines="$(echo $(echo "$cruft" | wc -l))"
        test -n "$verbosity" -a $verbosity -gt 6 \
          && {
            warn "Crufty: $(vc__stat "$1"):"
            printf "$cruft\n"
          } || {
            warn "Crufty: $(vc__stat "$1"), $cruft_lines path(s)"
          }
        return 2
      ;;

    * )
        error "pd_clean error"
        return -1
      ;;

  esac
}


