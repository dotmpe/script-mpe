#!/bin/sh

# Current tasks

htd_tasks_lib_load ()
{
  test -n "${TODOTXT_EDITOR-}" || {
    test -x "$(command -v todotxt-machine)" &&
      TODOTXT_EDITOR=todotxt-machine || TODOTXT_EDITOR=$EDITOR
  }
}

htd_tasks_lib_init ()
{
  test -n "${tasks_hub-}" -o -z "${PACKMETA-}" || htd_tasks_init
}

htd_tasks_init ()
{
  eval $(map=package_pd_meta_ package_sh tasks_hub)
}

htd_man_1__tasks='More context for todo.txt files - see also "htd help todo".

  Commands in this group:

    htd tasks grep
        Run over the source, aggregating tagged comments as "task lines".
    htd tasks local
        Run the projects preferred way to aggregate tasks, if none given
        run `tasks-grep`.
    htd tasks scan|grep|local|edit|buffers|hub
        Use tasks-local to bring local todo,done.txt documents in sync.
    htd tasks hub
        Aside from todor,done.txt, keep task lists files in "./to", dubbed the
        tasks-hub. See help for specific sub-commands.
    htd tasks edit
        Start editor session for todo,done.txt documents. Migrates requested
        tags to the items from the hub, *and* back again after the session.
        Every item that has a tag is sorted into an existing or new buffer.
    htd tasks buffers [ @Context | +project ]
        Given set of tags, list local paths to buffers.
        TODO: sort out scripts into tasks-backends
    htd tasks tags [todo] [done] [file..]
        List tags found on items in files. Like ``tasks-hub tagged`` except
        that checks every list in the hub. While this by default uses the local
        todo.txt/done.txt file, and any filename given as the third and following
        arguments
    htd tasks add-dates [--date=] [--echo] TODOTXT [date-def]
      Rewrite tasks lines, adding dates from SCM blame-log if non found.
      This sets the creation date(s) to the known author date,
      when the line was last changed.
    htd tasks sync SRC DEST
      Go over entries and update/add new(er) entries in SRC to DEST.
      SRC may have changes, DEST should have clean SCM status.

  Default: tasks-scan.
  See tasks-hub for more local functions.

  Print package pd-meta tags setting using:

    htd package pd-meta tags
    htd package pd-meta tags-document
    htd package pd-meta tags-done
    .. etc,

  See also package.rst docs.
  The first two arguments TODO/DONE.TXT default to tags-document and tags-done.
'
htd_flags__tasks=itAOlQ
htd_libs__tasks=package\ htd-tasks\ tasks
# lib_load os str std list vc tasks todo


htd_man_1__tasks_edit='Edit local todo/done.txt generated from to/do-{at,in}*

Tasks are migrated between the local todo/.done.txt and buffers (ie. all
to/do-at-<context>.list and to/do-in-<project>.list files found), moving
to the todo/done files before the edit session and back to the buffers after
closing it.

This serves as a first step to manage tasks existing across project borders, and
to use backends based on context. Ideally in this mode, every source is locked
for editing so at the end of the editor session each change is a simple update.
'
htd_spc__tasks_edit="tasks-edit TODO.TXT DONE.TXT [ @PREFIX... ] [ +PROJECT... ] [ ADDITIONAL-PATHS ]"
# This reproduces most of the essential todotxt-edit code, b/c before migrating
# we need exclusive access to update the files anyway.
htd_env__tasks_edit='
  tags=
  id=$htd_session_id migrate=${migrate-1} remigrate=${remigrate-1}
  todo_slug= todo_document= todo_done=
  tags= projects= contexts= buffers= add_files= locks=
  colw=${colw-32}
'
htd__tasks_edit()
{
  htd_tasks_edit "$@"
}
htd_flags__tasks_edit=epqlA
htd_libs__tasks_edit=htd-tasks
htd_argsv__tasks_edit=htd_argsv_tasks_session_start
htd_als__edit_tasks=tasks-edit


htd_man_1__tasks_hub='Given a tasks-hub directory, either get tasks, tags or
additional settings ie. backends, indices, cardinality.

  htd tasks-hub init
    Figure out identity for buffer lists
  htd tasks-hub be
    List the backend scripts, a hack on context "@be-" prefix..
  htd tasks-hub tags
    List tags for which local task buffers or backend/proc scripts exists.
    TODO: only list buffers, list scripts elsewhere. E.g backend
  htd tasks-hub tagged
    Lists the tags, from items in lists
  htd tasks-hub urlstat
    Iterate over hub files and scan for URLs, see htd urlstat list and checkall

'
htd_man_1__tasks_hub_tags='List tags for which buffers exist'
htd_env__tasks_hub='projects=${projects-1} contexts=${contexts-1}'
htd_spc__tasks_hub='tasks-hub [ (be|tags|tagged) [ ARGS... ] ]'
htd_spc__tasks_hub_taggged='tasks-hub tagged [ --all | --lists | --endpoints ] [ --no-projects | --no-contexts ] '
htd__tasks_hub()
{
  htd_tasks_hub "$@"
}
htd_flags__tasks_hub=eqiAOl
htd_libs__tasks_hub=tasks\ htd-tasks
htd_als__hub=tasks-hub


# TODO: introduce htd proc LIST
  # Lists are files with lines treated as items with rules applied.
  # Each list is associated with its own unique context(s)
  # If the context corresponds to a script it is used to manage the item.
  # Each lifecycle event can be hooked and trigger a reaction by the context.
  # By setting a default certain rules are always inherited.
  # The default list however is todo, or to/do. Also see, buy, fix, whatever.
  # Items remain in their list, and are considered dirty or uncommitted until
  # they have a context tag added. Setting a context rule for a list allows
  # to indicate a required context choice, to migrate items to the
  # appropiate list, and to note items that have no context.
  # With a dynamic context, automatic or interactive handling and cleanup is
  # possible for various sorts of items: tasks, reminders, references,
  # reports, etc. On the other hand it is also possible to generate lists,
  # filter, etc. E.g. directories, issues, packages, bookmarks, emails,
  # name it. Having the list-item formet here helps to integrate with e.g.
  # node-sitefile. Next; start thinking in structured tags, topics.
  # And then add support for containment, nesting, grouping.

htd_spc__tasks_process='process [ LIST [ TAG.. [ --add ] | --any ]'
htd_env__tasks_process='
  todo_slug=${todo_slug} todo_document=${todo_document} todo_done=${todo_done}
'
htd__tasks_process()
{
  #projects=0 htd__tasks_hub tags | tr -d '@' | while read ctx
  #do
  #  echo TODO process task arg ctx: $ctx
  #done
  tags="$(htd__tasks_tags "$@" | lines_to_words ) $tags"
  note "Process Tags: '$tags'"
  htd_tasks_buffers $tags | grep '\.sh$' | while read scr
  do
    test -e "$scr" || continue
    test -x "$scr" || { warn "Disabled: $scr"; continue; }
  done
  for tag in $tags
  do
    scr="$(htd_tasks_buffers "$tag" | grep '\.sh$' | head -n 1)"
    test -n "$scr" -a -e "$scr" || continue
    test -x "$scr" || { warn "Disabled: $scr"; continue; }

    echo tag=$tag scr=$scr
    #grep $tag'\>' $todo_document | $scr
    # htd_tasks__at_Tasks process line
    continue
  done
}
htd_flags__tasks_process=lA
htd_libs__tasks_process=htd-tasks
htd_argsv__tasks_process=htd_argsv_tasks_session_start
htd_als__tasks_proc=tasks-process
htd_als__process_tasks=tasks-process


# Given a list of tags, turn these into task storage backends. One path
# for reserved read/write access per context or project. See tasks.rst for
# the implemented mappings. Htd can migrate tasks between stores based on
# tag, or request new or remove existing tag Ids.
htd_man_1__tasks_buffers="For given tags, print buffer paths. "
htd_spc__tasks_buffers='tasks-buffers [ @Contexts... +Projects... ]'
htd__tasks_buffers()
{
  htd_tasks_buffers "$@"
}
htd_flags__tasks_buffers=l
htd_libs__tasks_buffers=htd-tasks


htd_man_1__tasks_session_start='Starts an editing session for TODO.txt lines.

With no tags given (@ or +) this will not do anything. But for each tag given
the lines are first migrated from its local buffer (in to/*.list or another
location) to the TODO.TXT file.

There is the idea to introduce an * or "all" value to accumulate every task,
but I think that easily becomes overkill.
'
htd_spc__tasks_session_start="tasks-session-start TODO.TXT DONE.TXT [ @PREFIX... ] [ +PROJECT... ] [ ADDITIONAL-PATHS ]"
htd_env__tasks_session_start="$htd_env__tasks_edit"
htd__tasks_session_start()
{
  stderr info "3.1. Env: $(var2tags \
    id todo_slug todo_document todo_done tags buffers add_files locks colw)"
  set -- $todo_document $todo_done
  assert_files $1 $2
  # Get tags too for current todo/done file, to get additional locks
  tags="$(tasks_todotxt_tags "$1" "$2" | lines_to_words ) $tags"
  note "Session-Start Tags: ($(echo "$tags" | count_words
    )) $(echo "$tags" )"
  stderr info "3.2. Env: $(var2tags \
    id todo_slug todo_document todo_done tags buffers add_files locks colw)"
  # Get additional paths to all files, look for todo/done buffer files per tag
  buffers="$(htd_tasks_buffers $tags )"
  # Lock files todo/done and additional-paths to buffers
  locks="$(lock_files $id "$@" $buffers $add_files | lines_to_words )"
  { exts="$TASK_EXTS" pathnames $locks ; echo; } | column_layout
  # Fail now if main todo/done files are not included in locks
  verify_lock $id $1 $2 || {
    released="$(unlock_files $id $@ $buffers | lines_to_words )"
    error "Unable to lock main files: $1 $2" 1
  }
  note "Acquired locks ($(echo "$locks" | count_words ))"
}


htd__tasks__src__exists()
{
  test -n "$2" || {
    echo
  }
  echo grep -srIq $1 $all $TASK_DIR/
}
htd__tasks__src__add()
{
  new_id=$(htd rndstr < /dev/tty)
  while htd__tasks__src__exists "$new_id"
  do
    new_id=$(htd rndstr < /dev/tty)
  done
  echo $new_id
}
htd__tasks__src__remove()
{
  false
}


htd_tasks__help ()
{
  #std_help tasks
  echo "$htd_man_1__tasks"
}

htd__tasks()
{
  eval set -- $(lines_to_args "$arguments") # Remove options from args
  test -z "${echo-}" || tasks_echo=$echo

  case "$1" in

# Read-only

    info )
        htd_tasks_load
        note "$(var2tags  todo_slug todo_document todo_done )"
      ;;

    be.src )
        mkvid "$2" ; cmid=$vid
        . ./to/be-src.sh ; shift 2
        htd__tasks__src__${cmid} "$@"
      ;;

    be* )
        be=$(printf -- "$1" | cut -c4- )
        test -n "$be" || error "No default tasks backend" 1
        mksid "$1" '' ''; ctxid=$sid
        test -e ./to/$sid.sh || error "No tasks backend '$1' ($be)" 1
        . ./to/$ctxid.sh ;
        mkvid "$be" ; beid=$vid
        mkvid "$2" ; cmid=$vid
        . ./to/$ctxid.sh ; shift 2
        htd__tasks__${beid}__${cmid} "$@"
      ;;

    tags ) shift ;  htd_tasks_tags "$@" ;;

    "" ) shift || true ; htd_tasks_scan "$@" ;;

# Modify/proc/update list

    add-dates ) req_fcontent_arg "$2"
        tasks_add_dates_from_scm_or_def "$2"  "$3"
      ;;

  sync ) req_fcontent_arg "$2"
        # TODO: req_clean_content_arg "$3"
        req_fcontent_arg "$3"
        tasks_sync_from_to "$2" "$3"
      ;;

# Default

    * )
        subcmd_prefs=${base}_tasks__\ ${base}_tasks_ try_subcmd_prefixes "$@"
      ;;
  esac
}

# htd_flags__tasks_session_start=epqiA
htd_argsv_tasks_session_start()
{
  htd_tasks_load
  std_info "1.1. Env: $(var2tags \
    id todo_slug todo_document todo_done tags buffers add_files locks colw)"
  test -n "$*" || return 0
  while test $# -gt 0 ; do case "$1" in
      '+'* ) tags="$tags $1" ; projects="$projects $1" ; shift ;;
      '@'* ) tags="$tags $1" ; contexts="$contexts $1" ; shift ;;
      '-'* ) define_var_from_opt "$1" ; shift ;;
      * )
          # Override doc/done with args 1,2.
          not_falseish "$override_doc" || { override_doc=1 ; test -z "$1" ||
            todo_document="$1" ; shift ; continue ; }
          not_falseish "$override_doc" || { override_done=1 ; test -z "$1" ||
            todo_done="$1" ; shift ; continue ; }
          add_files="$add_files $1" ; shift
        ;;
  esac ; done
  std_info "1.2. Env: $(var2tags \
      id todo_slug todo_document todo_done tags buffers add_files locks colw)"
}

htd_tasks_session_end()
{
  std_info "6.1 Env: $(var2tags \
      id todo_slug todo_document todo_done tags buffers add_files locks colw)"
  # clean empty buffers
  for f in $buffers
  do test -s "$f" -o ! -e "$f" || rm "$f"; done
  std_info "Cleaned empty buffers"
  test ! -e "$todo_document" -o -s "$todo_document" || rm "$todo_document"
  test ! -e "$todo_done" -o -s "$todo_done" || rm "$todo_done"
  # release all locks
  released="$(unlock_files $id "$1" "$2" $buffers | lines_to_words )"
  test -n "$(echo "$released")" && {
    note "Released locks ($(echo "$released" | count_words )):"
    { exts="$TASK_EXTS" pathnames $released ; echo; } | column_layout
  } || {
    warn "No locks to release"
  }
}


# Load from pd-meta.tasks.{document,done} [ todo_slug todo-document todo-done ]
htd_tasks_load()
{
  test -n "$1" || set -- init
  while test $# -gt 0 ; do case "$1" in

    init )
  eval $(map=package_pd_meta_tasks_:todo_ package_sh document done slug )
  test -n "$todo_document" || todo_document=todo.$TASK_EXT
  test -n "$todo_done" ||
    todo_done=$(pathname "$todo_document" $TASK_EXTS)-done.$TASK_EXT
  assert_files $todo_document $todo_done
  test -n "$todo_slug" || {
    # XXX local not accepted by osh $(map=package_ package_sh  id  )
    eval $(map=package_ package_sh  id  )
    test -n "$id" && {
      upper=1 mksid "$id"
      todo_slug="$sid"
    }
  }
  test -n "$todo_slug" || error todo-slug 1
  ;;

    tasks-hub | tasks-process )
  test -n "$tasks_hub" || { error "No tasks-hub env" ; return 1 ; }
  std_info "Hub: $tasks_hub"
  #test ! -e "./to" -o "$tasks_hub" = "./to" ||
  #  error "hub ./to left behind" 1
  ;;

    tags )
  eval $(map=package_pd_meta_ package_sh tags)
  test -n "$tasks_tags" ||
    tasks_tags="$(package_sh_list .package.sh pd_meta_tasks_tags \
      | lines_to_words )"
  ;;

    coops )
  eval $(map=package_pd_meta_ package_sh coops)
  test -n "$tasks_coops" ||
    tasks_coops="$(package_sh_list .package.sh pd_meta_tasks_coops \
      | lines_to_words )"
  ;;

    be* | proc* )
  ;;

    * ) error "tasks-load '$1'?" ;; esac ; shift ; done
}


htd_migrate_tasks()
{
  std_info "Migrating tags: '$tags'"
  echo "$tags" | words_to_lines | while read tag
  do
    test -n "$tag" || continue
    case "$tag" in

      +* | @* )
          buffer=$(htd_tasks_buffers $tag | head -n 1 )
          fileisext "$buffer" $TASK_EXTS || continue
          test -s "$buffer" || continue
          note "Migrating prj/ctx: $tag"
          htd_move_and_retag_lines "$buffer" "$1" "$tag"
        ;;

      * ) error "? '$?'"
        ;;
      # XXX: cleanup
      @be.src )
          # NOTE: src-backend needs to keep tag-id before migrating. See #2
          #SEI_TAGS=
          #grep -F $tag $SEI_TAG
          true
        ;;
      @be.* )
          #note "Checking: $tag"
          #htd_tasks_buffers $tag
          true
        ;;

    esac
  done
}


htd_remigrate_tasks()
{
  test -n "$1"  || error todo-document 1
  note "Remigrating tags: '$tags'"
  echo "$tags" | words_to_lines | while read tag ; do
    test -n "$tag" || continue
    case "$tag" in

      +* | @* )
          buffer=$(htd_tasks_buffers "$tag" | head -n 1)
          fileisext "$buffer" $TASK_EXTS || continue
          note "Remigrating prj/ctx: $tag"
          htd_move_tagged_and_untag_lines "$1" "$buffer" "$tag"
        ;;

      * ) error "? '$?'"
        ;;

      # XXX: cleanup
      @be.* )
          #note "Committing: $tag"
          #htd_tasks_buffers $tag
          true
        ;;

    esac
  done
}

# Update todo/tasks/plan document from local tasks
htd_tasks_scan() # tasks-scan [ --interactive ] [ --Check-All-Tags ] [ --Check-All-Files ]
{
  htd_tasks_load
  note "Scanning tasks.. ($(var2tags  todo_slug todo_document todo_done ))"
  local grep_Hn=$(setup_tmpf .grep-Hn)
  mkdir -vp $(dirname "$grep_Hn")
  { htd_tasks_local > $grep_Hn
  } || error "Could not update $grep_Hn" 1
  test -z "$todo_slug" && {
    warn "Slug required to update store for $grep_Hn ($todo_document)"
  } ||  {
    note "Updating tasks document.. ($todo_document $(var2tags verbose choice_interactive Check_All_Tags Check_All_Files))"
    tasks_flags="$(
      test -z "$verbosity" && {
        falseish "$verbose" || printf -- " -v ";
      } || printf -- " --verbosity $verbosity";
      falseish "$choice_interactive" || printf -- " -i ";
      falseish "$update" || printf -- " --update ";
    )"
    # FIXME: select tasks backend
    be_opt="-t $todo_document --link-all"
    #be_opt="--redis"
    tasks.py $tasks_flags -s $todo_slug read-issues \
      --must-exist -g $grep_Hn $be_opt \
        || error "Could not update $todo_document " 1
    note "OK. $(read_nix_style_file $todo_document | count_lines) task lines"
  }
  std_info "To-do: $(count_lines "$todo_document") items"
  std_info "Done: $(count_lines "$todo_done") items"
  test -s "$todo_document" || rm "$todo_document"
  test -s "$todo_done" || rm "$todo_done"
}

# Use the preferred local way of creating the local todo grep list
htd_tasks_local() # tasks-local [ --Check-All-Tags ] [ --Check-All-Files ]
{
  local tasks_grep=
  eval $(map=package_pd_meta_:htd_ package_sh tasks_grep)
  test -n "$htd_tasks_grep" && {
    Check_All_Tags=1 Check_All_Files=1  \
    $htd_tasks_grep
    return 0
  } || {
    htd_tasks_grep
  }
}

# Htd's built-in todo grep list command for local tasks
# Output is like 'grep -nH': '<filename>:<linenumber>: <line-match>'
htd_tasks_grep() # ~ [ --tasks-grep-expr | --Check-All-Tags] [ --Check-All-Files]
{
  local out=$(setup_tmpf .out)
  # NOTE: not using tags from metadata yet, need to build expression for tags
  trueish "${Check_All_Tags-}" && {
    test -n "${tasks_grep_expr-}" ||
      tasks_grep_expr='\<\(TODO\|FIXME\|XXX\)\>' # tasks:no-check
  } || {
    test -n "${tasks_grep_expr-}" || tasks_grep_expr='\<XXX\>' # tasks:no-check
  }
  test -e .git && src_grep="git grep -nI" || src_grep="grep -nsrI \
      --exclude '*.html' "
  # Use local settings to filter grep output, or set default
  eval local $(package_sh id pd_meta_tasks_grep_filter)
  test -n "$pd_meta_tasks_grep_filter" ||
    pd_meta_tasks_grep_filter="eval grep -v '\\<tasks\\>.\\<ignore\\>'"
  note "Grepping.. ($(var2tags \
    Check_All_Tags Check_All_Files tasks_grep_expr pd_meta_tasks_grep_filter))"
  $src_grep \
    $tasks_grep_expr \
  | $pd_meta_tasks_grep_filter \
  | while IFS=: read srcname linenr comment
  do
    grep -q '\<tasks\>.\<ignore\>.\<file\>' $srcname ||
    # Preserve quotes so cannot use echo/printf w/o escaping. Use raw cat.
    { cat <<EOM
$srcname:$linenr: $comment
EOM
    }
  done
}

htd_tasks_edit()
{
  std_info "2.1. Env: $(var2tags \
    id todo_slug todo_document todo_done tags buffers add_files locks colw)"
  htd__tasks_session_start "$todo_document" "$todo_done" "$@"
  std_info "2.2. Env: $(var2tags \
    id todo_slug todo_document todo_done tags buffers add_files locks colw)"
  # TODO: If locked import principle tasks to main
  trueish "$migrate" && htd_migrate_tasks "$todo_document" "$todo_done" "$@"
  # Edit todo and done file
  $TODOTXT_EDITOR "$todo_document" "$todo_done"
  # Relock in case new tags added
  # TODO: diff new locks
  #newlocks="$(lock_files $id "$1" | lines_to_words )"
  #note "Acquired additional locks ($(basenames ".list" $newlocks | lines_to_words))"
  # TODO: Consolidate all tasks to proper project/context files
  std_info "2.6. Env: $(var2tags \
    id todo_slug todo_document todo_done tags buffers add_files locks colw)"
  trueish "$remigrate" && htd_remigrate_tasks "$todo_document" "$todo_done" "$@"
  # XXX: where does @Dev +script-mpe go, split up? refer principle tickets?
  htd__tasks_session_end "$todo_document" "$todo_done"
}

htd_tasks_hub() # ~ [group]
{
  test -n "$1" || set -- be
  htd_tasks_load init $subcmd
  case "$1" in

    init )
        contexts=0 htd_tasks_hub tags | tr -d '+' | while read proj
        do
          for d in $projectdirs ; do test -d "$d/$proj" || continue
            (
              local todo_document=
              cd $d/$proj
              test -e todo.txt && todo_document=todo.txt || {
                eval $(map=pd_meta_tasks_:todo_ package_sh id document)
              }
              (
                test -n "$todo_document" || warn "no doc ($proj)" 1
                test -e $todo_document || warn "doc missing ($proj/$todo_document)" 1
              ) || continue
              note "Doc for $proj: $todo_document"
              htd_tasks_tags $todo_document
            )
          done
        done
      ;;

    be )
        note "Listing local backend configs"
        for be in $tasks_hub/*.sh
        do
          echo "@be.$(basename "$be" .sh | cut -c4-)"
        done
      ;;

    be.trc.* )
        mksid "$(echo "$1" | cut -c8-)" ; shift
        lib_load tasks-trc
        tasks__trc $sid "$@"
      ;;

    tags ) shift; test -n "$1" || set -- $tasks_hub/*.*
        tasks_hub_tags "$@"
      ;;

    tagged )
        # XXX: switch file selection like in tags above?
        test "$(echo $tasks_hub/*.*)" = "$tasks_hub/*.*" &&
          warn "No files to look for tags" ||
        tasks_todotxt_tags $tasks_hub/*.*
      ;;

    urlstat ) shift
        lib_load urlstat
        urlstat_check_update=$update
        urlstat_update_process=$process
        for buffer in $tasks_hub/*.*
        do
            urlstat_file="$buffer"
            urls_list "$urlstat_file" | Init_Tags="$*" urlstat_checkall
        done
      ;;

    * ) error "tasks-hub? '$*'" ;;
  esac
}

# List tags from task files (default to those from todo/done docs).
htd_tasks_tags() # List tags from task files ~ [Task-Docs...]
{
  test -n "$1" || {
    htd_tasks_load
    test -n "$2" || set -- $todo_done "$@"
    set -- $todo_document "$@"
  }
  assert_files $1 $2
  note "Tags for <$*>"
  tasks_todotxt_tags "$@"
}

htd_tasks_buffers()
{
  test -n "$1" || set -- $package_lists_contexts_default

  for tag in "$@"
  do
    case "$tag" in
      @be.* ) be=$(echo $tag | cut -c5- )
          echo $tasks_hubbe-$be.sh
        ;;
      +* ) prj=$(echo $tag | cut -c2- )
          echo $tasks_hubdo-in-$prj.list
          echo cabinet/done-in-$prj.list
          echo $tasks_hubdo-in-$prj.list
          echo cabinet/done-in-$prj.list
          echo $tasks_hubdo-in-$prj.sh
        ;;
      @* ) ctx=$(echo $tag | cut -c2- )
          echo $tasks_hubdo-at-$ctx.list
          echo cabinet/done-at-$ctx.list
          echo $tasks_hubdo-at-$ctx.list
          echo cabinet/done-at-$ctx.list
          echo $tasks_hubdo-at-$ctx.sh
          echo store/at-$ctx.sh
          echo store/at-$ctx.yml
          echo store/at-$ctx.yaml
        ;;
      '*' )
          echo \
              $tasks_hubdo-in-*.list \
              $tasks_hubdo-in-*.sh \
              $tasks_hubdo-at-*.list \
              $tasks_hubdo-at-*.sh \
              cabinet/done-in-*.list \
              cabinet/done-in-*.sh \
              cabinet/done-at-*.list \
              cabinet/done-at-*.sh \
              store/at-$ctx.sh  | words_to_lines
          #echo store/at-$ctx.yml
          #echo store/at-$ctx.yaml
        ;;
      * ) error "tasks-buffers '$tag'?" 1 ;;
    esac
  done
}
