### Helper to run Vim


# Run Vim command with output on stdout. Hides stderr so make sure command
# works.
vim_cmd_stdout () # ~ <Cmd>
{
  vim -c ':set t_ti= t_te= nomore' -c "$1"'|q!' 2>/dev/null
}

# Vim looks for help using './doc/tags' files on runtimepath. The tags file is
# created with 'helptags' command.
vim_doctags()
{
  vim_runtimepath | while read dir; do
    test -e $dir/doc/tags || continue
    echo $dir/doc/tags
  done
}

# List doc dirs on runtimepath
vim_docpath ()
{
  vim_runtimepath | while read dir; do
    test -e $dir/doc || continue
    echo $dir/doc
  done
}

# List running Vim instances and peek at open files
vim_openfiles ()
{
  vim_pids_do vim_swapfiles_forpid | sed 's/\/\.\([^\/]*\)\.swp$/\/\1/'
}

# Output script to set a pane-layout with file arg-1 top-left, arg-2 to the right, etc.
vim_panes_startupcmd () # Layout
{
  test -n "${1-}" || set -- "1.2-threepanes"

  # modes of equal divs with 2, 3 or 4 editor buffers
  case "$1" in

    1-twopanes ) # Two columns
        printf -- "+vs\nwincmd l\n:bn\n:wincmd h\n" ;;

    2-twopanes ) # Two rows
        printf -- ":sp\nwincmd j\n:bn\n:wincmd k\n" ;;

    1.2-threepanes ) # Full height left and one h-split right
        printf -- "+vs\nwincmd l\n:bn\n:sp\nwincmd j\n:bn\n"
        printf -- ":wincmd h\n" ;; # move back to first buffer

    3-fourpanes ) # Two columns, two h-splits each
        printf -- \
"+vs\n:sp\nwincmd j\n:bn\nwincmd l\n:bn\n:sp\n:bn\nwincmd j\n:bn\n:bn\n"
        printf ":wincmd h\n:wincmd k\n" # Move back to first buffer
      ;;

    * ) $LOG error "" "No such Vim layout" "$1" 1 ;;
  esac

  printf ":wincmd =\n"  # Equalize col/rows
}

# Write a VIM command file to configure editor on startup, and output the
# invocation argv for Vim like: '-c "source $sys_tmp/<Name-ID>.vimcmd"'
vim_prepare_session () # Name-ID Layout
{
  test $# -gt 0 -a -n "${1-}" || return 98
  vim_panes_startupcmd "$2" > $sys_tmp/$1.vimcmd
  printf -- '-c "source %s"' "$sys_tmp/$1.vimcmd"
}

vim_pids_do () # ~ [<Handler>] [<PId-cmdname>] # List Ids of all Vim processes (for user)
{
  local vph=${1:-echo} pidcmd=${2:-vim} fail=false
  for vim_pid in $(os_pids ${pidcmd})
  do
    $LOG info :vim:openfiles "Looking at Vim process" "$vph:$vim_pid"
    "$vph" "$vim_pid" || {
      $LOG warn :vim:openfiles "Error with handler" "E$?:$vph:$vim_pid"
      fail=true
    }
  done
  ! ${fail:?}
}

# vim 'echo &runtimepath' and strip-ansi escapes.
vim_runtimepath () #
{
  # XXX: did not check all below ANSI
  vim_cmd_stdout 'echo &runtimepath' | sed -r \
      -e "s/\x1B\[([0-9]{1,3}(;[0-9]{1,3})*)?[trmGKH]//g" \
      -e "s/\x1B\[([?][0-9][0-9]*)?[lh]//g" \
      -e "s/\x1B\[2J//g" \
      -e "s/\x1B(=|>)//g" \
          | tr -d '[:space:]' | tr ',' '\n'
}

vim_scriptnames () # ~ # List every Vim script loaded in standard instance
{
  vim_cmd_stdout 'scriptnames'
}

vim_swapfiles ()
{
  vim_pids_do vim_swapfiles_forpid
}

vim_swapfiles_forpid ()
{
  {
    test "${lsof_ignore_stderr:-1}" = 1 && {
      lsof -p "${1:?}" 2>/dev/null || return
    } || {
      lsof -p "${1:?}" || return
    }
  } | { grep 'u *REG' || return; } | awk '{print $9}'
}

vim_search () # ~ <Search-re>
{
  vim -c '/'"${1:?}"
}

#
