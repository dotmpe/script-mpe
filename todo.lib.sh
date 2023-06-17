#!/bin/sh

todo_lib__load ()
{
  sh_isset ggrep || . $scriptpath/tools/sh/parts/env-0-1-lib-sys.sh
}

todo_lib__init ()
{
  true "${package_pd_meta_tasks_document:=""}"
  true "${package_pd_meta_tasks_done:=""}"
  true "${package_todotxtm_src:="$UCONF/etc/todotxtm/*.ttxtm $UCONF/etc/todotxtm/project/*.ttxtm"}"
}


todo_env_init () # [todo-txt] ~
{
  test -n "${todo_txt-}" || {
    test -e .todo.txt && todo_txt=.todo.txt || {
        test -e todo.txt && todo_txt=todo.txt || {
          return 1
        }
    }
  }
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

# Should not re-open tasks. Insert date after closed and/or prio tags.
todo_txt_set_created()
{
  sed -E 's/^(x\ )?(\([^\)]+\) )?/\1\2'"$1"' /g'
}
