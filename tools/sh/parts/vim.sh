

# Run Vim command with output on stdout. Hides stderr so make sure command
# works.
vim_cmd_stdout () # ~ <Cmd>
{
  vim -c ':set t_ti= t_te= nomore' -c "$1"'|q!' 2>/dev/null
}
# Copy: vim.lib:

#
