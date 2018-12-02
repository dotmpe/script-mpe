#!/bin/sh

todo_lib_load()
{
  sh_isset ggrep
}

# Get std. ISO date-only spec. For extend specs including time and
# year/week see todo-txt-grep-dt-id
todo_txt_grep_date()
{
  $ggrep -oE '^|\<([0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9])\>|$'
}
todo_txt_grep_dt_id()
{
  false # TODO: grep-dt-id
}
