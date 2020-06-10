# Run VIM command with output on stdout. Hides stderr so make sure command
# works.
vim_cmd_stdout () # Cmd
{
  vim -c ':set t_ti= t_te= nomore' -c "$1"'|q!' 2>/dev/null
}

vim_scriptnames() #
{
  vim_cmd_stdout 'scriptnames'
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
