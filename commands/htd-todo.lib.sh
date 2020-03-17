htd_man_1__todo='Edit and mange todo.txt/done files.

(todo is an alias for tasks-edit, see help tasks-edit for command usage)

Other commands:

  todotxt tree - TODO: treeview
  todotxt list|list-all - TODO: files in UCONFDIR
  todotxt count|count-all - count in UCONFDIR
  todotxt edit

   todo-clean-descr
   todo-read-line

  todotxt-edit
  todotxt-tags
  todo-gtags

  htd build-todo-list
'

htd_als__todo=tasks-edit


htd_man_1__todotxt_edit='Edit local todo/done.txt

Edit task descriptions. Files do not need to exist. First two files default to
todot.txt and .done.txt and will be created.

This locks/unlocks all given files before starting the $TODOTXT_EDITOR, which
gets to edit only the first two arguments. The use is to aqcuire exclusive
read-write on todo.txt tasks which are included in other files. See htd tasks
for actually managing tasks spread over mutiple files.
'
htd_spc__todotxt_edit="todotxt-edit TODO.TXT DONE.TXT [ ADDITIONAL-PATHS ]"
htd__todotxt_edit()
{
  test -n "$1" || {
    test -n "$2" || set -- .done.txt "$@"
    set  -- todo.txt "$@"
  }
  local colw=32 # set column-layout width
  assert_files $1 $2
  # Lock main files todo/done and additional-paths
  local id=$htd_session_id
  locks="$(lock_files $id "$@" | lines_to_words )"
  note "Acquired locks:"
  { basenames ".list" $locks ; echo ; } | column_layout
  # Fail now if main todo/done files are not included in locks
  verify_lock $id $1 $2 || {
    unlock_files $id "$@"
    error "Unable to lock main files: $1 $2" 1
  }
  # Edit todo and done file
  $TODOTXT_EDITOR $1 $2
  # release all locks
  released="$(unlock_files $id "$@" | lines_to_words )"
  note "Released locks"
  { basenames ".list" $released ; echo; } | column_layout
}
htd_als__tte=todotxt-edit
#htd_run__todo=O


htd__todotxt()
{
  test -n "$UCONFDIR" || error UCONFDIR 15
  test -n "$1" || set -- edit
  case "$1" in

    # Print
    tree ) # TODO: somekind of todotxt in tree view?
      ;;

    list|list-all )
        for fn in $UCONFDIR/todotxtm/*.ttxtm $UCONFDIR/todotxtm/project/*.ttxtm
        do
          fnmatch "*done*" "$fn" && continue
          test -s "$fn" && {
            echo "# $fn"
            cat $fn
            echo
          }
        done
      ;;

    count|count-all )
        # List paths below current (proj/dirs with txtm files)
        { for fn in $UCONFDIR/todotxtm/*.ttxtm $UCONFDIR/todotxtm/project/*.ttxtm
          do
            fnmatch "*done*" "$fn" && continue
            cat $fn
          done
        } | wc -l
      ;;

    edit ) htd__todotxt_edit "$2" "$3" ;;

    tags ) shift 1; tasks_todotxt_tags "$@" ;;

  esac
}


# Experimenting with gtasks.. looking at todo targets
htd__todo_gtasks()
{
  test -e TODO.list && {
    cat TODO.list | \
      grep -Ev '^(#.*|\s*)$' | \
      while read line
      do
        todo_read_line "$line"
        todo_clean_descr "$comment"
        echo "$fn $ln  $tag  $descr"
        # (.,.)p
      done
  } || {
    echo
    echo "..Htdocs ToDo.."
    gtasks -L -dsc -dse -sn
    echo "Due:"
    gtasks -L -sdo -dse -sn
#  echo ""
#  gtasks -L -sb tomorrow -sa today -dse
  }
}


htd_grep_line_exclude()
{
  grep -v '.*\ htd:ignore\s*'
  # TODO: build lookup util for ignored file line ranges
  #| while read line
  #do
  #    file=$()
  #    linenr=$()
  #    htd__htd_excluded_line $file $linenr
  #done
}


htd_man_1__build_todo_list="Build indented file of path/line/tag from FIXME: etc tagged
src files"
htd__build_todo_list()
{
  test -n "$1" || set -- TODO.list "$2"
  test -n "$2" || {
    test -s .app-id \
        && set -- "$1" "$(cat .app-id)" \
        || set -- "$2" "$(basename "$(pwd)")"
  }

  { for tag in FIXME TODO NOTE XXX # tasks:no-check
  do
    grep -nsrI $tag':' . \
        | grep -v $1':' \
        | htd_grep_line_exclude \
        | while read line;
      do
        tid="$(echo $line | sed -n 's/.*'$tag':\([a-z0-9\.\+_-]*\):.*/\1/p')"
        test -z "$tid" \
            && echo "$(pwd);$2#$tag;$line" \
            || echo "$(pwd);$2#$tag:$tid;$line";

      done
  done; } | todo-meta.py import -
}

#
