#!/bin/sh
#
# Htdocs: work in progress 'daily' shell scripts
#

htd_src=$_
test -z "$__load_lib" || set -- "load-ext"

set -e

version=0.0.3-dev # script-mpe


htd__inputs="arguments prefixes options"
htd__outputs="passed skipped error failed"

htd_load()
{
  # -- htd box load insert sentinel --
  test -n "$EDITOR" || EDITOR=vim
  test -n "$DOC_EXT" || DOC_EXT=.rst
  test -n "$HTD_GIT_REMOTE" || HTD_GIT_REMOTE=default
  test -n "$CWD" || CWD=$(pwd)
  test -n "$UCONFDIR" || UCONFDIR=$HOME/.conf/
  test -n "$TMPDIR" || TMPDIR=/tmp/
  test -n "$HTDIR" || HTDIR=$HOME/public_html
  test -n "$HTD_ETC" || HTD_ETC=$(htd_init_etc|head -n 1)
  test -n "$HTD_TOOLSFILE" || HTD_TOOLSFILE=$CWD/tools.yml
  test -n "$HTD_TOOLSDIR" || HTD_TOOLSDIR=$HOME/.htd-tools
  test -n "$HTD_JRNL" || HTD_JRNL=personal/journal
  test -n "$FIRSTTAB" || export FIRSTTAB=50

  test -d "$HTD_TOOLSDIR/bin" || mkdir -p $HTD_TOOLSDIR/bin
  test -d "$HTD_TOOLSDIR/cellar" || mkdir -p $HTD_TOOLSDIR/cellar

  req_htdir

  test -e .package.sh && . .package.sh

  go_to_directory .projects.yaml && {
    cd $CWD
    # $go_to_before
    #PROJECT="$(basename $(pwd))"
  } || {
    cd $CWD
  }

  #test -e
  #grep -qF $PROJECT':'  ../.projects.yaml || {
  #  warn "No such project prefix $PROJECT"
  #}

  _14MB=14680064
  _6MB=7397376
  _5k=5120

  #test -n "$MIN_SIZE" || MIN_SIZE=1
  test -n "$MIN_SIZE" || MIN_SIZE=$_6MB

  TODAY=+%y%m%d0000
  _1HR_AGO=+%y%m%d0000
  _15MIN_AGO=+%y%m%d0000
  _5MIN_AGO=+%y%m%d0000


  test -n "$hostname" || hostname="$(hostname -s | tr 'A-Z' 'a-z')"
  test -n "$uname" || uname="$(uname -s)"

  test "$CWD" = "$(pwd -P)" || warn "current path seems to be aliased ($CWD)"

  test -e table.sha1 && R_C_SHA3="$(cat table.sha1|wc -l)"

  stdio_type 0
  test "$stdio_0_type" = "t" && {
    rows=$(stty size|awk '{print $1}')
    cols=$(stty size|awk '{print $2}')
  } || {
    rows=32
    cols=79
  }

  test -n "$htd_tmp_dir" || htd_tmp_dir=$(setup_tmpd)
  test -n "$htd_tmp_dir" || error "htd_tmp_dir load" 1
  fnmatch "dev*" "$ENV" || {
    test "$(echo $htd_tmp_dir/*)" = "$htd_tmp_dir/*" || {
      rm -r $htd_tmp_dir/*
    }
  }

  htd_rules=~/.conf/rules/$hostname.tab
  ns_tab=$HOME/.conf/namespace/$hostname.tab

  which tmux 1>/dev/null || {
    export PATH=/usr/local/bin:$PATH
  }

  which rst2xml 1>/dev/null && rst2xml=$(which rst2xml) || {
    which rst2xml.py 1>/dev/null && rst2xml=$(which rst2xml.py) ||
      warn "No rst2xml"
  }

  test -n "$htd_session_id" || htd_session_id=$(htd__uuid)
  test -n "$choice_interactive" || choice_interactive=1

  local flags="$(try_value "${subcmd}" run | sed 's/./&\ /g')"
  for x in $flags
  do case "$x" in

    a ) # argv-handler: use method to process arguments

        local htd_args_handler="$(eval echo "\$$(try_local $subcmd argsv)")"
        case "$htd_args_handler" in

          arg-groups* ) # Read in '--' separated argument groups, ltr/rtl
            test "$htd_args_handler" = arg-groups-r && dir=rtl || dir=ltr

            local htd_arg_groups="$(eval echo "\$$(try_local $subcmd arg-groups)")"

            # To read groups from the end instead,
            test $dir = ltr \
              || { set -- "$(echo "$@" | words_to_lines | reverse_lines )"; }
            test $dir = ltr \
              || htd_arg_groups="$(words_to_lines $htd_arg_groups | reverse_lines )"

            for group in $htd_arg_groups
            do
                while test -n "$1" -a "$1" != "--"
                do
                  echo "$1" >>$arguments.$group
                  shift
                done
                shift

              test -s $arguments.$groups || {
                local htd_defargs="$(eval echo "\$$(try_local $subcmd defargs-$group)")"
                test -z "$htd_defargs" \
                  || { echo $htd_defargs | words_to_lines >>$arguments.$group; }
              }
            done
            test -z "$DEBUG" || wc -l $arguments*

          ;; # /arg-groups*
        esac
      ;; # /argv-handler

    A )
        # Set default args or filter. Value can be literal or function.
        local htd_default_args="$(eval echo "\$$(try_local $subcmd argsv)")"
        test -n "$htd_default_args" && {
          $htd_default_args "$@"
        }
      ;;
    o ) # process optsv
        local htd_optsv="$(eval echo "\"\$$(try_local $subcmd optsv)\"")"
        test -s "$options" && {
          $htd_optsv
        } || noop
      ;;
    f ) # failed: set/cleanup failed varname
        export failed=$(setup_tmpf .failed)
      ;;
    i ) # io-setup: set all io varnames
        setup_io_paths -$subcmd-${htd_session_id}
        export $htd__inputs $htd__outputs
      ;;
    m )
        # TODO: Metadata blob for host
        metadoc=$(statusdir.sh assert)
        exec 4>$metadoc.fkv
      ;;
    p )
        test -e package.yaml && update_package
        test -e .package.sh && . .package.sh
        test -n "$package_id" && {
          note "Found package '$package_id'"
        } || {
          package_id="$(basename "$(realpath .)")"
          note "Using package ID '$package_id'"
        }
      ;;
    P )
        local prereq_func="$(eval echo "\"\$$(try_local $subcmd pre)\"")"
        test -z "$prereq_func" || $prereq_func $subcmd
      ;;
    S )
        # Get a path to a storage blob, associated with the current base+subcmd
        S=$(try_value "${subcmd}" S)
        test -n "$S" \
          && status=$(setup_stat .json "" ${subcmd}-$(eval echo $S)) \
          || status=$(setup_stat .json)
        #test -s $status || echo '{}' >$status
        exec 5>$status.pkv
      ;;

    x ) # ignores, exludes, filters
        htd_load_ignores
      ;;

    esac
  done

  # load extensions via load/unload function
  for ext in $(try_value "${subcmd}" load)
  do
    htd_load_$ext || warn "Exception during loading $subcmd $ext"
  done
}

htd_unload()
{
  local unload_ret=0
  for x in $(try_value "${subcmd}" run | sed 's/./&\ /g')
  do case "$x" in

    i ) # remove named IO buffer files; set status vars
        clean_io_lists $htd__inputs $htd__outputs
        htd_report $htd__inputs $htd__outputs || subcmd_result=$?
      ;;

    S )
        exec 5<&-
        test -s $status || echo '{}' >$status
        test ! -s $status.pkv \
          || {
        cat $status.pkv
            jsotk.py update --pretty $status $status.pkv
            rm $status.pkv
          }
        test ! -e $status.pkv || rm $status.pkv
        unset status
      ;;

    P )
        local postreq_func="$(eval echo "\"\$$(try_local $subcmd post)\"")"
        test -z "$postreq_func" || $postreq_func $subcmd
      ;;

    r )
        # Report on scriptnames and associated script-lines provided in $HTD_TOOLSFILE
        statusdir.sh dump $report | jsotk.py -O yaml --pretty dump -
      ;;

  esac; done

  clean_failed || unload_ret=1

  for var in $(try_value "${subcmd}" vars)
  do
    eval unset $var
  done
  test -n "$htd_tmp_dir" || error "htd_tmp_dir unload" 1
  #test "$(echo $htd_tmp_dir/*)" = "$htd_tmp_dir/*" \
  #  || warn "Leaving HtD temp files $(echo $htd_tmp_dir/*)"
  unset htd_tmp_dir

  return $unload_ret
}


# Misc. load functions


htd_load_ignores()
{
  # Initialize one HTD_IGNORE file.
  ignores_load
  test -n "$HTD_IGNORE" -a -e "$HTD_IGNORE" \
    || error "expected $base ignore dotfile" 1

  lst_init_ignores
  lst_init_ignores .names
  #match_load_table vars
}

htd_load_xsl()
{
  test -z "$xsl_ver" && {
    test -x "$(which saxon)" &&
      xsl_ver=2 ||
      xsl_ver=1
  } || {
    test xsl_ver != 2  ||
      test -x "$(which saxon)" ||
        error "Saxon required for XSLT 2.0" 1
  }
  note "Set XSL proc version=$xsl_ver.0"
}



# Main aliases

htd_als__init=pd-init
#htd_als__install=install-tool
htd_als__update=update-checksums
#htd_als__check=pd-check
htd_als__doctor=check
htd__check()
{
  htd__find_empty || stderr ok "No empty files"
  htd pd-check
  # TODO check (some) names htd_name_precaution
  # TODO run check-files
  # htd check-names
  htd__ck_validate sha1
}
htd__fsck()
{
  htd__ck_validate sha1
}

htd__make()
{
  cd $HTDIR && make $*
}
htd_als__mk=make



# Static help echo's

htd_usage()
{
  echo "$scriptname.sh Bash/Shell script helper"
  echo 'Usage: '
  echo "  $scriptname <cmd> [<args>..]"
  echo ""
  echo "Possible commands are listed by help-commands or commands. "
  echo "The former is hard-coded and more documented but possibly stale."
  echo "The latter long listing is generated en-passant from the source"
  echo "documents, and the parsing maybe buggy. "
}
htd__help_commands()
{
  echo 'Commands: '
  echo '  home                             Print htd dir.'
  echo '  info                             Print vars.'
  echo '  mk|make                          Run make (in htd dir).'
  echo '  st|stat                          Run make stat.'
  echo '  sys                              Run make sys.'
  echo '  edit-today                       Run htd today and start editor.'
  echo '  today [<prefix> [<ext>]]         Create symlinks of the format $PREFIX/{today,tomorrow,yesterday}.rst -> %Y-%m-%d.rst'
  echo ''
  echo 'Virtuals: '
  echo '  vbox-start <name>                Start headless VBoxVM for VM UUID with name in VBoxVM table. '
  echo '  vbox-suspend <name>              Suspend VBoxVM. '
  echo '  vbox-reset <name>                Reboot VBoxVM. '
  echo '  vbox-stop <name>                 Stop VBoxVM. '
  echo '  vbox-list                        List known and unknown VMs. '
  echo '  vbox-running                     List running VMs. '
  echo '  vbox-info [<name>]'
  echo ''
  echo '  lists [opts]                     List all lists. '
  echo '  tasks [<list>..]                 List tasks in lists'
  echo '  new-task <list> <title>          Add task to list with title'
  echo '  task-note <list> <num>           Edit notes of task in the $EDITOR'
  echo '  task-title <list> <num> [<title>]'
  echo '                                   Get or update title of task'
  echo '  done <list> <num>                Toggle task completed status'
  echo '  todo                             '
  echo ''
  echo 'Networking'
  echo '  wol <host>                       Send wol to mac for host from WOL table.'
  echo '  mac                              List ARP table: hwaddr for clients (once) connector to LAN. '
  echo ''
  echo 'File Versioning'
  echo '  git-remote [repo]                List all names remotely, or give the SSH url for given repo. '
  echo '  git-init-remote [repo]           Initialze remote bare repo if local path is GIT project'
  echo '  git-remote-info                  Show current ~/.conf/git-remotes/* vars.'
  echo '  git-files [REPO...] GLOB...      Look for file (pattern) in repositories'
  echo ''
  echo 'Working tree utils'
  echo '  check-names [. [<tags>]]         Check names in path, according to tags.'
  echo '  list-paths [-d|-f|-l] [.|<dirpath]'
  echo '                                   List all paths, including dirs. '
  echo '  test-name <path>                 Test filename for unhandled characters. '
  echo '  find-name <path|localname>       TODO: Given (partial) path, try to find the file using find.  '
  echo '  update                           Fill checksums tables for all local files. TODO: find out what there is to know about file using settings, other commands, ext. tooling & services. And trigger resolve'
  echo '  '
  echo 'Rules'
  echo '  resolve                          XXX based on data and settings, pre-process and mark all files ready for commit, and bail on any irregularities. '
  echo '  commit                           XXX record metadata according to htd settings/commands. Commit is only a success, if the entire tree is either clean or ignored. '
  echo '  show-rules [<path>]              tabulate all rules that would apply to path'
    echo '  run-rules [<path>]               (re-)run rules on path'
  echo '  add-rule <pattern> <functions>|<script> '
  echo '                                   Add either function and inline script to run for every path matching pattern. '
  echo ''
  echo 'Working tree metadata'
  echo '  ck-init                          Initialize new checksum table'
  echo '  ck-consolidate [.|<path>]        TODO: integrate metadata from all metafiles (see ck-metafile)'
  echo '  ck-metafile <path>               TODO: integrate metadata from .meta/.rst/.sha1sum/etc.'
  echo ''
  echo 'Working tree checksum metadata [CK_TABLE=./]'
  echo "  ck-table [ck|md5|sha1] <path>    Tell if checksum exists for file, don\'t validate or update"
  echo '  ck-table-subtree [ck|md5|sha1] <path> '
  echo '                                   Like ck-table, but this takes a partial path starting at the root level and returns the checksum records for files below that'
  #echo '  ck-check [ck|md5|sha1]           Iterate table, move lines with non-existant paths to .missing table'
  #echo '  ck-fix [.|<path>]                TODO: If path exists, look for duplicates using ck-find-content and move this path to .duplicates marking it to be resolved interactively'
  #echo '                                   Or if path is missing, try find-name to find new location. If still missing, look for any copy using ck-find-content and move current entry to table .duplicate on success, or .gone on failure'
  #echo '  ck-check-missing [ck|md5|sha1]   TODO: see ck-clean; iterate .missing table, and call ck-fix. Move checksum to .gone if file stays missing'
  #echo '  ck-purge [|missing|duplicate|gone] TODO: drop missing-paths from indicate tables'
  #echo '  ck-dedup <path>                  With no path given, iterate the duplicate table. Otherwise deduplicate content, using given path as preferred location. '
  #echo '  ck-find-content <path>           TODO: Given path, try find-name or checksum tables and annex-backend to find copies and give all alternate locations. '
  echo '  ck-update [ck|md5|sha1] (<path>) Iterate all files, and create checksum table records for unknown files'
  echo '  ck-drop [ck|mk5|sha1] <path>     Remove row for given path from checksum table'
  echo '  ck-validate [ck|md5|sha1]        Verify each file by generating and comparing its checksum'
  echo '  ck-cksum [TABLE]                 check file size and cksum'
  echo '  ck-prune                         Drop non-existant paths from table, copy to .missing'
  echo '  ck-clean [ck|md5|sha1]           TODO: iterate .gone table, and call ck-fix. Move gone checksum if file stays missing'
  echo '  ck-metafile                      TODO: consolidate meta files'
  echo '  ck-torrent TORRENT               Check torrent download'
  echo ''
  echo 'System'
  echo '  ls-volumes                       Go over local online disks, see that '
  echo '                                   services symlinks are in place'
  echo ''
  echo 'Other commands: '
  other_cmds
}
other_cmds()
{
  echo '  -E|edit-main                     Edit this script.'
  echo '  -e|edit                          Edit a local document or script.'
  echo '  alias                            Show bash aliases for this script.'
  echo '  -h|help                          Give a combined usage, command and docs. '
  echo '  docs                             Echo manual page. '
  echo '  commands                         Echo this comand description listing.'
  echo "  usage                            List all commands. "
  echo "  info                             List env info. "
  echo "  files                            List file used by htd. "
  echo '  mk|make                          Run make (in htd dir).'
  echo '  vt|edit-today                    '
  echo '  n|edit-node ID TAGS              '
  echo '  nnl|edit-note-nnl ID TAGS        '
  echo '  nen|edit-note-en ID TAGS         '
}


# Help (sub)commands:

htd__help_docs()
{
  echo "Docs:"
  echo ""
}

htd__help_files()
{
  echo "Files"
  echo ""
  echo "    From config settings:"
  echo "  $vbox_names (\$vbox_names)"
  echo "  $wol_hwaddr (\$wol_hwaddr)"
  echo ""
  echo "    From CWD:"
  echo "  ./TODO.list"
  echo "  ./table.names"
  echo "  ./invalid.paths"
  echo "    TODO: uses path .git/.."
  echo "    TODO: paths used by matchbox"
  echo ""
  echo "    Temporary left after exec:"
  echo "  /tmp/gtasks-\$list-\$num-note"
  echo ""
  echo "    Config files"
  echo "  ~/.conf/git-remotes/\$HTD_GIT_REMOTE.sh"
  echo "  ~/.conf/rules/\$host.sh"
  echo ''
  echo 'See dckr for container commands and vc for GIT related. '
}

htd_man_1__commands="List all commands"
htd__commands()
{
  choice_global= choice_all=true std__commands
}


htd_man_1__help="Echo a combined usage, command and docs"
htd_spc__help="-h|help [<id>]"
htd__help()
{
  test -z "$1" && {
    htd_usage
    echo ''
    echo 'Other commands: '
    other_cmds
  } || {
    echo_help $1
  }
}
htd_als___h=help
htd_als____help=help


htd_man_1__version="Version info"
htd__version()
{
  echo "$package_id/$version"
}
htd_als___V=version


htd__home()
{
  echo $HTDIR
}

htd__info()
{
  echo "env"
  echo "  CWDIR"
  echo "    If set, use instead of the current directory for working dir. "
  echo ""
  log "Script:                '$(pwd)/$scriptname'"
  log "User Config Dir:       '$UCONFDIR' [UCONFDIR]"
  log "User Public HTML Dir:  '$HTDIR' [HTDIR]"
  log "Current workingdir:    '$CWDIR' [CWDIR]"
  log "Project ID:            '$PROJECT' [PROJECT]"
  log "Minimum filesize:      '$(( $MIN_SIZE / 1024 ))'"
  log "Editor:                '$EDITOR' [EDITOR]"
  log "Default GIT remote:    '$HTD_GIT_REMOTE' [HTD_GIT_REMOTE]"
  log "Ignored paths:         '$HTD_IGNORE' [HTD_IGNORE]"
}

htd__expand()
{
  test -n "$1" || return 1
  for x in $1
  do
    test -e "$x" && echo $x
  done
}


htd_man_1__edit_main="Edit the main script file"
htd_spc__edit_main="-E|edit-main"
htd__edit_main()
{
  local evoke= files="$@"
  locate_name ;
  [ -n "$fn" ] || error "expected $scriptname?" 1
  files="$files $fn \
    $(dirname $fn)/$(basename "$fn").lib.sh \
    $(dirname $fn)/$(basename "$fn").rst \
    $(dirname $fn)/*.lib.sh"
  test "$EDITOR" = "vim" && {
    # Two vertical panes, with h-split in the right
    evoke="vim -O2 \
      -c "'":wincmd l"'" \
      -c :sp \
      -c "'"wincmd j"'" \
      -c :bn \
      -c "'"wincmd h"'
  }
  printf "$evoke $files"
  bash -c "$evoke $files"
}
htd_als___E=edit-main


htd_man_1__edit="Edit a local file, or abort"
htd_spc__edit="-e|edit <id>"
htd__edit()
{
  test -n "$1" || error "search term expected" 1
  doc_path_args
  find_paths="$(doc_find_name "$1")"
  grep_paths="$(doc_grep_content "$1")"
  test -n "$find_paths" -o -n "$grep_paths" \
    || error "Nothing found to edit" 1
  $EDITOR $find_paths $grep_paths
}
htd_als___e=edit


htd_man_1__find="Find file by name, or abort.

Searches every integrated source for a filename: volumes, repositories,
archives. See 'search' for looking inside files. "
htd_spc__find="-f|find <id>"
htd__find()
{
  test -n "$1" || error "name pattern expected" 1
  test -z "$2" || error "surplus argumets '$2'" 1

  note "Compiling ignores..."
  local find_ignores="$(find_ignores $HTD_IGNORE)"

  note "Looking in all volumes"
  for v in /srv/volume-[0-9]*-[0-9]*
  do
    vr="$(cd "$v"; pwd -P)"
    note "Looking in $v ($vr)..."

    # NOTE: supress output of any permision, non-existent or other IO error
    eval find "$vr" -iname "$1" 2>/dev/null

    #echo find $v $find_ignores -o -iname "$1" -a -print
    #eval find $v "$find_ignores -o \( -type l -o -type f \) -a -print "
    #echo "\l"
  done

  note "Looking in repositories"
  htd git-files "$1"
}
htd_als___f=find


htd_man_1__count="Look for doc and count. "
htd_spc__count="count"
htd__count()
{
  doc_path_args

  info "Counting files with matching name '$1' ($paths)"
  doc_find_name "$1" | wc -l

  info "Counting matched content '$1' ($paths)"
  doc_grep_content "$1" | wc -l
}


htd_man_1__find_doc="Look for document. "
htd_spc__find_doc="-F|find-doc (<path>|<localname> [<project>])"
htd__find_doc()
{
  doc_path_args

  info "Searching files with matching name '$1' ($paths)"
  doc_find_name "$1"

  info "Searching matched content '$1' ($paths)"
  doc_grep_content "\<$1\>"
}
htd_als___F=find-doc


htd__volumes()
{
  TODO "list as ansi/txt htd__srv_list"
}


htd_man_1__pd_init="TODO: Shortcut for pd init"
htd_spc__pd_init="pd-init"
htd_run__pd_init=fSm
htd__pd_init()
{
  echo
}


htd_man_1__pd_check="Shortcut for pd check in several dirs..."
htd_spc__pd_check="pd-check"
htd_run__pd_check=fSm
htd__pd_check()
{
  # Home
  local dirs="Desktop Downloads bin .conf"
  for dir in $dirs
  do
    cd ~/$dir
    pd check
  done
  for dir in htdocs
  do
    cd /Volumes/Zephyr/$dir
    pd check
  done
}


htd_man_1__status="Short status for current working directory"
htd_spc__status="status"
htd_run__status=fSm
htd_load__status=""
htd__status()
{
  test -n "$failed" || error failed 1

  stderr note "local-names: "
  # Check local names
  {
    htd check-names ||
      echo "htd:check-names" >>$failed
  } | tail -n 1

  stderr note "current-paths: "
  # See open paths below cwd using lsof
  htd__current_paths

  # Create list of open files, and show differences on subsequent calls
  #htd__open_paths

  note "Open-paths SCM status: "

  # Check open gits
  htd__open_paths | while read path
  do
    test -e $path/.git || {
      ~/project/mkdoc/usr/share/mkdoc/Core/log.sh \
              "header3" "$path" ""
      continue
    }
    ~/project/mkdoc/usr/share/mkdoc/Core/log.sh \
            "header3" "$path" "" "$( cd $path && vc.sh flags )"
    #$scriptpath/std.lib.sh ok "$path"
  done

  # FIXME: maybe something in status backend on open resource etc.
  #htd__recent_paths
  #htd__active

  stderr note "text-paths for main-docs: "
  # Check main document elements
  {
    test ! -d "$HTD_JRNL" ||
      EXT=$DOC_EXT htd__archive_path $HTD_JRNL
    htd__main_doc_paths "$1"
  } | while read tag path
  do
    test -e $path || continue
    htd tpath-raw $path
  done

  # TODO:
  #  global, local services
  #  disks, annex
  #  project tests, todos
  #  src, tools

  # TODO: rewrite to htd proj/vol/..-status
  #( cd ; pd st ) || echo "home" >> $failed
  #( cd ~/project; pd st ) || echo "project" >> $failed
  #( cd /src; pd st ) || echo "src" >> $failed

  test -s "$failed" -o -s "$errored" && stderr ok "htd stat OK" || noop
}
htd_als__st=status
htd_als__stat=status


htd__volume_status()
{
  htd__context
}

htd__project_status()
{
  htd__context
}

htd__workdir_status()
{
  htd__context
  finfo.py --metadir .meta
}

htd_als__metadirs=context
htd_man_1__context="TODO find packages, .meta dirs"
htd__context()
{
  test -n "$1" || set -- "$(pwd)"
  while test -n "$1"
  do
    test -e $1/.meta && echo $1/.meta
    test "$p" != "/" || break
    p=$1
    shift
    test "$p" = "$(cd "$p"; pwd -P)" && {
      set -- "$(dirname "$p")"
    } || {
      set -- "$(dirname "$(cd "$p";pwd -P)")" "$(dirname "$p")"
    }
  done
}


htd_man_1__script="Get/list scripts in $HTD_TOOLSFILE. Statusdata is a mapping of
  scriptnames to script lines. See Htd run and run-names for package scripts. "
htd_spc__script="script"
htd_run__script=pSmr
htd_S__script=\$package_id
htd__script()
{
  tools_json || return $?

  # Force regeneration for stale data
  test $status -ot $HTD_TOOLSFILE \
    && statusdir.sh reset $status

  # FIXME: statusdir tools script listing
  rm $status
  # Regenerate status data for this script if not available
  statusdir.sh exists $status || {
    scripts="$( jsotk.py keys -O lines $HTD_TOOLSFILE tools )"

    for toolid in $scripts
    do
      note "Scriptlines for '$toolid': "

      jsotk.py -q path --is-str $HTD_TOOLSFILE tools/$toolid && {
        scriptline="$(jsotk.py path -O py $HTD_TOOLSFILE "tools/$toolid")"
        note "Line: '$scriptline'"
        echo "tools/$toolid/scripts/$toolid[]=$scriptline" 1>&5
        echo "scripts[]="$toolid 1>&5
        continue
      }

      # If object, our tool can either be a required package a named script
      # using oner And/or incidentally be the same name for an executable.
      (
        jsotk.py -q path --is-obj $HTD_TOOLSFILE tools/$toolid ||
        jsotk.py -q path --is-new $HTD_TOOLSFILE tools/$toolid
      ) && {

        jsotk.py objectpath -O lines $HTD_TOOLSFILE '$..*[@.scripts."'$toolid'"]' \
          | while read scriptline
          do
            note "Line: '$scriptline'"
            echo "tools/$toolid/scripts/$toolid[]=$scriptline" 1>&5
          done

        #echo "scripts[]="$toolid 1>&5
        continue
      }

      jsotk.py -q path --is-list $HTD_TOOLSFILE tools/$toolid && {
        jsotk.py items -O py $HTD_TOOLSFILE "tools/$toolid" \
          | while read scriptline
          do
            note "Line: '$scriptline'"
            echo "tools/$toolid/scripts/$toolid[]=$scriptline" 1>&5
          done
        echo "scripts[]="$toolid 1>&5
        continue
      }
    done
  }

  # TODO: generate script to run. This keeps a JSON blob associated with
  # htd-script and the script-mpe package ($HTD_TOOLSFILE). Gonna want a JSON
  # for shell scripts/aliases/etc. Also validation.

  #    while test -n "$1"
  #    do
  #      jsotk.py objectpath -O py $HTD_TOOLSFILE '$..*[@.scripts."'$1'"]'
  #      shift
  #    done
  report=$status
}

htd_man_1__tools="Scan wether given binaries are installed. "
htd_spc__tools="tools <tool-id>.."
htd__tools()
{
  (
    cd $HOME/.conf
    test -e $HTD_TOOLSFILE
    tools_json || return $?
    test -n "$1" || set -- $(echo $(jsotk.py -O lines keys tools.json tools))
    echo "tools:"
    while test -n "$1"
    do
      installed tools.json "$1" \
        && echo "- $1 (installed)" \
        || echo "- $1"
      shift
    done
  )
}

htd_man_1__install=""
htd_spc__install="install [TOOL...]"
htd__install()
{
  tools_json || return $?
  local verbosity=6
  while test -n "$1"
  do
    install_bin tools.json $1 \
      && info "Tool $1 is installed" \
      || info "Tool $1 error: $?"
    shift
  done
}
htd__uninstall()
{
  tools_json || return $?
  local verbosity=6
  while test -n "$1"
  do
    uninstall_bin tools.json "$1" \
      && info "Tool $1 is not installed" \
      || { r=$?;
        test $r -eq 1 \
          && info "Tool $1 uninstalled" \
          || info "Tool uninstall $1 error: $r" $r
      }
    shift
  done
}
htd__installed()
{
  tools_json || return $?
  installed tools.json "$1" && note "Tool '$1' is present"
}

htd__man_5__htdignore_merged='Exclude rules used by `htd find|edit|count`, compiled from other sources using ``htd init-ignores``. '

htd_man_1__init_ignores="Write all exclude rules to .htdignores.merged"
htd__init_ignores()
{
  htd_init_ignores
}


htd_man_1__relative_path="Test for relative path"
htd__relative_path()
{
  # TODO: maybe build relative path from 1 arg and cwd, or two args
  # see also mkrlink. Also clean up.
  #x_re "${1:0:2}" '[\.\/]*' && echo ok || echo nok
  htd_relative_path $1
  r=$?
  echo relpath=$relpath
  exit $r
}
htd_man_1__relpath="Alias for 'relative-path'"
htd_als__relpath='relative-path'


# XXX: add config files
htd__man_5_table_names=""

htd__test_find_path_locals()
{
    htd_find_path_locals table.names $1
    echo path_locals=$path_locals

    htd_find_path_locals table.names $1 $(pwd)
    echo path_locals=$path_locals
}

# List root IDs
htd__list_local_ns()
{
  fixed_table_hd $ns_tab ID PATH CMD | while read vars
  do
    eval local "$vars"
    echo $ID
  done
}

# XXX: List matching tags
htd_spc__ns_names='ns-names [<path>|<localname> [<ns>]]'
htd__ns_names()
{
  test -z "$3" || error "Surplus arguments: $3" 1
  fixed_table_hd $ns_tab ID CMD_PATH CMD | while read vars
  do
    eval local "$vars"
    test -n "$2" && {
      echo 2=$2
      test "$2" = "$ID" || continue
    }
    cd $CMD_PATH
    note "In '$ID' ($CMD_PATH)"
    eval $CMD "$1"
    cd $CWD
  done
}

# TODO: List resources containing tag
htd__ns_resources()
{
  set --
}


# Run a sys-* target in the main htdocs dir.
htd__make_sys()
{
  cd $HTDIR
  for x in $*
  do
    make system-$x
  done
}

htd__build()
{
  rm -f $(setup_tmpd)/htd-out
  htd__make build 2>1 | capture_and_clear
  echo Mixed output::
  echo
  cat $(setup_tmpd)/htd-out | sed  's/^/    /'
}

# show htd shell aliases
htd__alias()
{
  grep '\<'$scriptname'\>' ~/.alias | grep -Ev '^(#.*|\s*)$' | while read _a A
  do
    a_id=$(echo $A | awk -F '=' '{print $1}')
    a_shell=$(echo $A | awk -F '=' '{print $2}')
    echo -e "   $a_id     \t$a_shell"
  done
}


# Open an editor to edit todays log
# For argument accepts ids for journal names other than the default personal/journal
# TODO: make file entry for directory, deflist for file
# TODO: accept multiple arguments, and global ID's for certain log dirs/files
# TODO: maintain symbolic dates in files, absolute and relative (Yesterday, Saturday, 2015-12-11 )
htd__edit_today()
{
  # XXX: remove
  #{ test -n "$HTDIR" && test -d "$HTDIR" ; } \
  #  || error "HTDIR empty or missing: $HTDIR" 1
  test -n "$EXT" || EXT=.rst
  local pwd=$(pwd) arg=$1

  #cd $HTDIR

  test -n "$1" || set -- journal/

  fnmatch "*/" "$1" && {

    case "$1" in *journal* )
      set -- $HTD_JRNL
    ;; esac

    test -e "$1" || \
      set -- "$pwd/$1"
    test -e "$1" || \
      error "unknown dir $1" 1

  } || {

    # Look for here and in pwd, or create in pwd; if ext matches filename

    test -e "$1" || \
      set -- "$pwd/$1"

    test -e "$1" || \
      fnmatch "*.$EXT" "$1"  && touch $1

    # Test in htdir with ext
    test -e "$1" || set -- "$arg$EXT"

    # Test in pwd with ext
    test -e "$1" || set -- "$pwd$1$EXT"

    # Create in pwd (with ext)
    test -e "$1" || touch $1
  }

  # Open of dir causes default formatted filename+header created
  test -d "$1" && {
    {
      note "Editing $1"
      #git add $1/[0-9]*-[0-9][0-9]-[0-9][0-9].rst
      htd__today "$1"
      today=$(realpath $1/today.rst)
      test -s "$today" || {
        title="$(date_fmt "" '%A %G.%V')"
        htd_rst_doc_create_update "$today" "$title"
      }
      # FIXME: bashism since {} is'nt Bourne Sh, but csh and derivatives..
      FILES=$(bash -c "echo $1/{today,tomorrow,yesterday}$EXT")
      htd_edit_and_update $(realpath $FILES)
    } || {
      error "err $1/ $?" 1
    }
  # Open of archive file cause day entry added
  } || {
    {
      local Y=%Y MSEP=- M=%m DSEP=- D=%d r=
      local date_fmt="$Y$MSEP$M$DSEP$D"
      local \
        today="$(date_fmt "" $date_fmt)"

      grep -qF $today $1 || {
        printf "$today\n  - \n\n" >> $1
      }

      $EDITOR $1
      git add $1
    } || {
      error "err file $?" 1
    }
  }
}
htd_als__vt=edit_today


# TODO consolidate with today, split into days/week/ or something
htd__archive_path()
{
  test -n "$1" || set -- "$(pwd)/cabinet"
  test -d "$1" || {
    fnmatch "*/" "$1" && {
      error "Dir $1 must exist" 1
    } ||
      test -d "$(dirname "$1")" ||
        error "Dir for base $1 must exist" 1
  }
  fnmatch "*/" "$1" || set -- "$(strip_trail $1)"

  # Default pattern: "$1/%Y-%m-%d"
  test -n "$base" -a -n "$name" || {
    test -n "$Y" || Y=/%Y
    test -n "$M" || M=-%m
    test -n "$D" || D=-%d
    #test -n "$EXT" || EXT=.rst
    test -d "$1" &&
      ARCHIVE_DIR=$1/ ||
      ARCHIVE_DIR=$(dirname $1)/
    ARCHIVE_BASE=$1$Y
    ARCHIVE_ITEM=$M$D$EXT
  }
  local f=$ARCHIVE_BASE$ARCHIVE_ITEM

  datelink -1d "$f" ${ARCHIVE_DIR}yesterday$EXT
  echo yesterday $datep
  datelink "" "$f" ${ARCHIVE_DIR}today$EXT
  echo today $datep
  datelink +1d "$f" ${ARCHIVE_DIR}tomorrow$EXT
  echo tomorrow $datep

  unset datep target_path
}
# declare locals for unset
htd_vars__archive_path="Y M D EXT ARCHIVE_BASE ARCHIVE_ITEM datep target_path"

# update yesterday, today and tomorrow links
htd__today()
{
  test -n "$1" || set -- "$(pwd)/journal" "$2" "$3" "$4"
  test -n "$2" || set -- "$1" "-" "$3" "$4"
  test -n "$3" || set -- "$1" "$2" "-" "$4"
  test -n "$4" || set -- "$1" "$2" "$3" "/"
  test -d "$1" || error "Dir $1 must exist" 1
  fnmatch "*/" "$1" || set -- "$1/"

  # Append pattern to given dir path arguments
  local YSEP=/ Y=%Y MSEP=- M=%m DSEP=- D=%d r=$1$YSEP
  test -n "$EXT" || EXT=.rst
  set -- "$1$YSEP$Y$MSEP$M$DSEP$D$EXT"

  datelink -1d "$1" ${r}yesterday$EXT
  datelink "" "$1" ${r}today$EXT
  datelink +1d "$1" ${r}tomorrow$EXT

  for tag in sunday monday tuesday wednesday thursday friday saturday
  do
    datelink "$tag -7d" "$1" "${r}last-$tag$EXT"
    datelink "$tag +7d" "$1" "${r}next-$tag$EXT"
    datelink "$tag" "$1" "${r}$tag$EXT"
  done

  note "Today: $today"
}


htd_als__week=this-week
htd__this_week()
{
  echo
}


# TODO: use with edit-local
htd__edit_note()
{
  test -n "$1" || error "ID expected" 1
  test -n "$2" || error "tags expected" 1
  test -z "" || error "surplus arguments" 1

  id="$(printf "$1" | tr -cs 'A-Za-z0-9' '-')"
  #id="$(echo "$1" | sed 's/[^A-Za-z0-9]*/-/g')"

  case " $2 " in *" nl "* | *" en "* ) ;;
    * ) set -- "$1" "$2 en" ;; esac
  fnmatch "* rst *" " $2 " || set -- "$1" "$2 rst"
  ext="$(printf "$(echo $2)" | tr -cs 'A-Za-z0-9_-' '.')"

  note=~/htdocs/note/$id.$ext
  htd_rst_doc_create_update $note "$1"
  htd_edit_and_update $note
}
htd_als__edit_note=n

htd__edit_note_nl()
{
  htd__edit_note "$1" "$2 nl" || return $?
}
htd_als__nnl=edit-note-nl

htd__edit_note_en()
{
  htd__edit_note "$1" "$2 en" || return $?
}
htd_als__nen=edit-note-en

# Print existing candidates to use as main document
htd__main_doc_paths()
{
  local candidates="$(htd_main_files)"
  test -n "$1" && {
    fnmatch "* $1$DOC_EXT *" " $candidates " &&
      set -- $1$DOC_EXT ||
        error "Not a main-doc $1"

  } || set -- "$candidates"
  for x in $@; do
    test -e "$x" || continue
    set -- "$x"; break; done
  echo "$(basename "$1" $DOC_EXT) $1"
}

# Edit first candidates or set to main$DOC_EXT
htd__main_doc()
{
  # Find first standard main document
  test -n "$1" || set -- "$(htd__main_doc_paths "$1"|read tag path)"
  test -n "$1" || set -- main$DOC_EXT

  local cksum=
  htd_rst_doc_create_update $1
  htd_edit_and_update $files $(htd_main_files|cut -d' ' -f2)

}
htd_als__md=main-doc



### VirtualBox

vbox_names=~/.conf/vbox/vms.sh
htd__vbox()
{
  name=$1
  [ -z "$name" ] && {
    htd__vbox_list
  } || {
    declare $(echo $(cat $vbox_names))
    uuid=$(eval echo \$$name)
    test -n "$uuid" || error "No such vbox VM '$name'" 1
  }
}

htd__vbox_start()
{
  test -n "$1" || error "VM name required" 1
  htd__vbox $1
  VBoxManage startvm ${uuid} --type headless \
      || error "Headless-start of VM $name" 1 \
      && log "Headless-start of VM $name completed successfully"
}

htd__vbox_start_console()
{
  test -n "$1" || error "VM name required" 1
  htd__vbox $1
  VBoxManage startvm ${uuid} \
      || error "Console-start of VM $name" 1 \
      && log "Console-start of VM $name completed successfully"
}

htd__vbox_reset()
{
  test -n "$1" || error "VM name required" 1
  htd__vbox $1
  VBoxManage controlvm ${uuid} reset \
      || error "Reset of VM $name" 1 \
      && log "Reset of VM $name completed successfully"
}

htd__vbox_stop()
{
  test -n "$1" || error "VM name required" 1
  htd__vbox $1
  VBoxManage controlvm ${uuid} poweroff \
      || error "Power-off of VM $name" 1 \
      && log "Power-off of VM $name completed successfully"
}

htd__vbox_suspend()
{
  test -n "$1" || error "VM name required" 1
  htd__vbox $1
  VBoxManage controlvm ${uuid} savestate \
      || error "Save-state of VM $name" 1 \
      && log "Save-state of VM $name completed successfully"
}

htd__vbox_list()
{
  VBoxManage list vms | \
    sed 's/^"\(.*\)"\ {\(.*\)}$/\2 \1/' | while read uuid name
  do
    grep $uuid $vbox_names >> /dev/null || echo unknown $name =$uuid
  done
  cat $vbox_names | \
    grep -Ev '^\s*(#.*|\s*)$'
}

htd__vbox_running()
{
  VBoxManage list runningvms
}

htd__vbox_info()
{
  test -n "$1" && {
    htd__vbox $1
    #2: --details --machinereadable
    VBoxManage showvminfo ${uuid} $2
  } || {
      for sub in intnets bridgedifs hostonlyifs natnets dhcpservers
      do log "Showing $sub"; VBoxManage list $sub; done
  }
}

htd__vbox_gp()
{
  htd__vbox "$1"
  VBoxManage guestproperty enumerate ${uuid}
  #VBoxManage guestproperty get ${uuid} "/VirtualBox/GuestInfo/Net/0/V4/IP"
}


# Wake a remote host using its ethernet address
wol_hwaddr=~/.conf/wol/hosts-hwaddr.sh
htd__wol_list_hosts()
{
  cat $wol_hwaddr
  error "Expected hostname argument" 2
}
htd__wake()
{
  host=$1
  [ -z "$host" ] && {
    htd__wol_list_hosts
  } || {
    local $(echo $(cat $wol_hwaddr))
    hwaddr=$(eval echo \$$host)
    [ -n "$hwaddr" ] || exit 4
    wakeonlan $hwaddr
    echo ":WOL Host: \`$host <$hwaddr>\`_"
  }
}

htd_spc__shutdown='shutdown [ HOST [ USER ]]'
htd__shutdown()
{
  echo
  # Boreas
  #sudo umount /Volumes/WDElements-USB-2T-3-1T7
  #run_cmd vs1 'shutdown -h now'
#  run_cmd dandy 'sudo shutdown -h now'
}


htd__ssh()
{
  case "$1" in
    vdckr )
        cd ~/.conf/dckr/ubuntu-trusty64-docker/
        vagrant ssh || vagrant up
        vagrant ssh
      ;;
    vdckr-mpe )
        cd ~/.conf/dckr/ubuntu-trusty64-docker-mpe/
        vagrant ssh || vagrant up
        vagrant ssh
      ;;
  esac
}


# Simply list ARP-table, may want something better like arp-scan or an nmap
# script
htd__mac()
{
  arp -a
}

# Current tasks

# Update todo/tasks/plan document from local tasks
htd_run__tasks=i
htd__tasks()
{
  local $(package_sh \
    id \
    pd_meta_tasks_slug \
    pd_meta_tasks_document || error "Missing package.sh var(s)" 1 )

  test -n "$pd_meta_tasks_document" || pd_meta_tasks_document=tasks.ttxtm
  test -n "$pd_meta_tasks_slug" || {
    test -n "$id" \
      && pd_meta_tasks_slug="$(printf -- "$id" | tr 'a-z' 'A-Z' | tr -sc 'A-Z0-9_-' '-')"
  }
  test -n "$pd_meta_tasks_slug" || error "Project slug required" 1
  local comments=$(setup_tmpf .comments)
  mkdir -vp $(dirname "$comments")
  (
    { test -e .git && git ls-files || pd list-paths --tasks; } \
      | xargs radical.py run-embedded-issue-scan \
        --issue-format full-sh > $comments
  ) || error "Could not update $comments" 1
  wc -l $comments
  tasks.py -v -s $pd_meta_tasks_slug read-issues \
    -g $comments -t $pd_meta_tasks_document \
      || error "Could not update $pd_meta_tasks_document" 1
  note "OK. $(count_lines $pd_meta_tasks_document) open tasks"
}

htd__todo()
{
  htd__todotxt edit
}

# Edit local/new task descriptions
htd_als__tte=todotxt-edit
htd__todotxt_edit()
{
  test -n "$UCONFDIR" || error UCONFDIR 12
  test -n "$hostname" || error hostname 12
  #test -n "$domain" || error domain 12

  var_isset ttxtm_fn || local ttxtm_fn= ttxtm_done_fn=

  ttxtm_fn=.todo.ttxtm ttxtm_done_fn=.done.ttxtm

  trueish "$choice_local" && {
    touch $ttxtm_fn $ttxtm_done_fn
  } || {
    ttxtm_fn=
    ttxtm_done_fn=
  }

  #trueish "$choice_global" && ttxtm_fn=$UCONFDIR/todotxtm/global.ttxtm
  #trueish "$choice_host" && ttxtm_fn=$UCONFDIR/todotxtm/$hostname.ttxtm
  #trueish "$choice_domain" && ttxtm_fn=$UCONFDIR/todotxtm/$domain.ttxtm

  mkcid "$(pwd)"
  local id=$cid

  #trueish "$choice_ext" && ttxtm_fn=$UCONFDIR/todotxtm/$hostname-$id.ttxtm

  test -n "$ttxtm_fn" -o ! -e "$ttxtm_fn" && {

    # Set filenames from project
    {
      { test -z "$choice_package" || trueish "$choice_package"; } && test -e package.yaml
    } && {
      local metaf=package.yaml
      local package_id=$( jsotk.py -I yaml objectpath $metaf '$.*[@.main is not None]' \
        | jsotk.py -O py path - "id" )

      # Set ext. ttxtm file for project
      ttxtm_fn=$UCONFDIR/todotxtm/project/$package_id.ttxtm
      ttxtm_done_fn=$UCONFDIR/todotxtm/project/$package_id-done.ttxtm

    } || {

      # Or, look for host/path
      test -n "$ttxtm_fn" -a -e "$ttxtm_fn" || {
        ttxtm_fn=$( \
          for fn in $UCONFDIR/todotxtm/$hostname$id.ttxtm \
            $UCONFDIR/todotxtm/$hostname.ttxtm \
            $UCONFDIR/todotxtm/global.ttxtm
          do
            test -e "$fn" && { echo $fn; break; }
          done )
      }
    }

    test -n "$ttxtm_fn" || error ttxtm_fn 12

    ttxtm_done_fn=./$(dirname $ttxtm_fn)/$(basename "$ttxtm_fn" .ttxtm)-done.ttxtm
  }

  for fn in $ttxtm_fn $ttxtm_done_fn
  do
    test -n "$fn" || continue
    test -e $fn || {
      test -z "$(dirname $fn)" || mkdir -vp $(dirname $fn)
      touch $fn
    }
  done

  todotxt-machine $ttxtm_fn $ttxtm_done_fn
}
#htd_run__todo=o

htd__todotxt()
{
  test -n "$UCONFDIR" || error UCONFDIR 12
  test -n "$1" || set -- edit
  case "$1" in

    # Print
    tree )
      ;;
    list|list-all )
        for fn in $UCONFDIR/todotxtm/*.ttxtm $UCONFDIR/todotxtm/project/*.ttxtm
        do
          fnmatch "*done.ttxtm" "$fn" && continue
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
            fnmatch "*done.ttxtm" "$fn" && continue
            cat $fn
          done
        } | wc -l
      ;;
    edit )
        local ttxtm_fn= ttxtm_done_fn=
        htd__todotxt_edit
        htd__todotxt_tags
      ;;
  esac
}

htd__todotxt_tags()
{
  # TODO: update/match with tag, project index
  test -e "$ttxtm_fn" && {
    grep -o '+[^\ ]*' $ttxtm_fn | words_to_lines
    grep -o '@[^\ ]*' $ttxtm_fn | words_to_lines
  }
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

todo_clean_descr()
{
  echo "$@" | \

  tag_grep_1='^.*(TODO|XXX|FIXME)[\ \:]*(.*)((\?\ )|(\.\ )|(\.\s*$)).*$' # tasks:no-check
  tag_grep_2='s/^.*(TODO|XXX|FIXME)[\ \:]*(.*)((\?\ )|(\.\ )|(\.\s*$)).*$/\1 \2\3/' # tasks:no-check
  tag_grep_3='s/^.*(TODO|XXX|FIXME)[\ \:]*(.*)$/\1 \2/' # tasks:no-check

  grep -E "$tag_grep_1" > /dev/null && {
    clean=$( echo "$@" | sed -E "$tag_grep_2" )
  } || {
    clean=$( echo "$@" | sed -E "$tag_grep_3" )
  }
  tag=$(echo $clean|cut -f 1 -d ' ')
  descr="$(echo ${clean:$(( ${#tag} + 1 ))})"
  test -n "$descr" -a "$descr" != " " && {
    echo $descr | grep -E '(\.|\?)$' > /dev/null || {
      set --
      # TODO: scan lines for end...
    }
  }
}

todo_read_line()
{
  line="$1"
  fn=$(echo $line | cut -f 1 -d ':')
  ln=$(echo $line | cut -f 2 -d ':')
  test "$ln" -eq "$ln" 2> /dev/null \
    || error "Please include line-numbers in the TODO.list" 1
  comment=${line:$((  ${#fn} + ${#ln} + 2  ))}
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


# Lists and tasks

gtasks_list_arg()
{
    test -z "$1" && list=Standaardlijst || list="$1"
}
gtasks_num_arg()
{
    test -z "$1" && return 1 || num="$1"
}
gtasks_list_opt()
{
  test -z "$1" && {
    list="-l Standaardlijst"
  } || {
    test "${1:0:1}" = "-" && {
      # possibly use verbatim opts (-L)
      list="$1"
    } || {
      list="-l $1"
    }
  }
}
gtasks_opts()
{
  cnt=0
  gtasks_opts=
  while test "${1:0:1}" = "-"
  do
    gtasks_opts="$gtasks_opts $1"
    cnt=$(( $cnt + 1 ))
    shift 1
  done
  return $cnt
}


# List all lists
htd__lists()
{
  test -n "$gtasks_opts" || gtasks_opts="-dsc"
  gtasks -ll $gtasks_opts
}

# List tasks in lists
htd__gtasks()
{
  gtasks_opts $@
  shift $?
  test -n "$gtasks_opts" || gtasks_opts="-dsc"
  test -z "$1" && {
    gtasks_list_opt
    gtasks $list $gtasks_opts
  }
  while test -n "$1"
  do
    gtasks_list_opt $@ && shift 1
    gtasks $list $gtasks_opts
  done
}

# Add task to list with title
htd__new_task()
{
  gtasks_list_arg $1 && shift 1
  gtasks -l "$list" -a - -t "$@"
}

# Edit notes of a task in the $EDITOR
htd__gtask_note()
{
  gtasks_list_arg $1 && shift 1
  gtasks_num_arg $1 && shift 1 || exit 1
  tmpf=/tmp/gtasks-$list-$num-note
  title="$(gtasks -dsc -l "$list" -gt $num)"
  mkdir -p $(dirname $tmpf)
  gtasks -dsc -l "$list" -gn $num > $tmpf.current
  check_pre=$(md5sum $tmpf.current | cut -f 1 -d ' ')
  echo -e "$title\n" > $tmpf.txt
  cat $tmpf.current >> $tmpf.txt
  $EDITOR $tmpf.txt
  new_title=$(head -n 1 $tmpf.txt)
  tail -n +3 $tmpf.txt > $tmpf.new
  check=$(md5sum $tmpf.new | cut -f 1 -d ' ')
  test "$title" != "$new_title" && {
    printf "Updating title ... "
    gtasks -l "$list" -e $num -t "$new_title" -dsl
  } || {
    echo "No changes to title. "
  }
  test "$check_pre" != "$check" && {
    printf "Updating notes ... "
    gtasks -l "$list" -e $num -n "$(cat $tmpf.new)" -dsl
  } || {
    echo "No changes to notes. "
  }
}

# Get or updte title of task
htd__gtask_title()
{
  gtasks_list_arg $1 && shift 1
  gtasks_num_arg $1 && shift 1 || exit 1
  test -z "$1" && {
    gtasks -dsc -l "$list" -gt $num
  } || {
    gtasks -dsc -l "$list" -e $num -t "$1"
  }
}

# Toggle task completed status
htd__done()
{
  test -n "$2" && {
    test "$2" -gt 0 && {
      gtasks_list_arg $1 && shift 1
      gtasks_num_arg $1 && shift 1 || exit 1
    }
  } || {
    test -n "$1" -a "$1" -gt 0 && {
      # default list
      gtasks_list_arg
      gtasks_num_arg $1 && shift 1 || exit 1
    }
  }
  gtasks -dsc -l "$list" -c $num
}


# Read urls for local files from file. If url is local dir, then
# use that to change CWD.
htd__urls_list()
{
  local cwd=$(pwd) file=
  htd_urls_args "$@"
  grep '\([a-z]\+\):\/\/.*' $file | while read url fn
  do
    test -d "$cwd/$url" && {
      cd $cwd/$url
      continue
    }
    test -n "$fn" || fn="$(basename "$url")"
    sha1ref=$(printf $url | sha1sum - | cut -d ' ' -f 1)
    md5ref=$(printf $url | md5sum - | cut -d ' ' -f 1)
    #echo $sha1ref $md5ref $url
    test -e "$fn" && {
      note "TODO: check checksum for file $fn"
    } || {
      warn "No file '$fn'"
    }
  done
}

htd__urls_get()
{
  local cwd=$(pwd) file=
  htd_urls_args "$@"
  read_nix_style_file "$file" | while read url fn utime size checksum
  do
    test -d "$cwd/$url" && {
      cd $cwd/$url
      continue
    }
    test -n "$fn" || fn="$(basename "$url")"
    test -e "$fn" || {
      wget -q "$url" -O "$fn" && {
        test -e "$fn" && note "New file $fn"
      } || {
        error "Retrieving file $fn"
      }
    }
  done
}

htd_urls_args()
{
  test -n "$1" && file=$1 || file=urls.list
  test -e "$file" || error urls-list-file 1
}

htd__urls()
{
  test -n "$1" || set -- list
  local act=$1; shift
  case "$act" in
    get )
        htd__urls_get "$@" || return $?
      ;;
    list )
        htd__urls_list "$@" || return $?
      ;;
    * ) error "No action '$act' for Htd urls"
        return 4
      ;;
  esac
}

# init or list SSH based remote

source_git_remote()
{
  test -n "$1" || set -- "$HTD_GIT_REMOTE"
  . ~/.conf/git-remotes/$1.sh \
      || error "Missing 1=$1 script" 1
}

htd__git_remote_info()
{
  test -n "$1" || set -- "$HTD_GIT_REMOTE"
  source_git_remote "$1"
  echo remote.$1.dir=$remote_dir
  echo remote.$1.host=$remote_host
  echo remote.$1.user=$remote_user
}
htd__git_remote()
{
  test -n "$2" && {
    source_git_remote $1; shift 1
  } || source_git_remote

  [ -z "$1" ] && {
    # List values for first arguments
    ssh_cmd="cd $remote_dir; ls | grep '.*.git$' | sed 's/\.git$//g' "
    ssh $ssh_opts $remote_user@$remote_host "$ssh_cmd"
  } || {
    repo=$1
    #git_url="ssh://$remote_host/~$remote_user/$remote_dir/$repo.git"
    scp_url="$remote_user@$remote_host:$remote_dir/$repo.git"
    echo $scp_url
  }
}

htd__git_init_remote()
{
  test -n "$HTD_GIT_REMOTE" || error "No HTD_GIT_REMOTE" 1
  source_git_remote
  [ -n "$1" ] && repo="$1" || repo="$(basename "$(pwd)")"
  test -n "$repo" || error "Missing project ID" 1

  ssh_cmd="mkdir -v $remote_dir/$repo.git"
  ssh $remote_user@$remote_host "$ssh_cmd"

  [ -e .git ] || error "No .git directory, stopping remote init" 0

  htd__git_remote $repo >> /dev/null
  test -n "$scp_url" || error "No scp_url" 1

  BARE=../$repo.git
  TMP_BARE=1
  [ -d $BARE ] && TMP_BARE= || {
    [ -d /src/$repo.git ] && {
      TMP_BARE=
      BARE=/src/$repo.git
    } || {
      log "Creating temp. bare clone"
      git clone --bare . $BARE
    }
  }

  [ -n "$TMP_BARE" ] || {
    log "Using existing bare repository to init remote: $BARE"
  }

  log "Syning new bare repo to $scp_url"
  rsync -azu $BARE/ $scp_url
  [ -n "$TMP_BARE" ] && {
    log "Deleting temp. bare clone ($BARE)"
    rm -rf $BARE
  }

  log "Adding new remote, and fetching remote refs"
  git remote add $HTD_GIT_REMOTE $scp_url
  git fetch $HTD_GIT_REMOTE

  log "Added remote $HTD_GIT_REMOTE $scp_url"
}

htd__git_drop_remote()
{
  [ -n "$1" ] && repo="$1" || repo="$PROJECT"
  log "Checking if repo exists.."
  ssh_opts=-q
  htd__git_remote | grep $repo || {
    error "No such remote repo $repo" 1
  }
  source_git_remote
  log "Deleting remote repo $remote_user@$remote_host:$remote_dir/$repo"
  ssh_cmd="rm -rf $remote_dir/$repo.git"
  ssh -q $remote_user@$remote_host "$ssh_cmd"
  log "OK, $repo no longer exists"
}


# List everything in  HTD_GIT_REMOTE repo collection

# Warn about missing src or project
htd__git_missing()
{
  htd__git_remote | while read repo
  do
    test -e /src/$repo.git \
      || warn "No src $repo" & continue

    test -e /srv/project-local/$repo \
      || warn "No checkout $repo"

  done
}

# Create local bare in /src/
htd__git_init_src()
{
  htd__git_remote | while read repo
  do
    fnmatch "*annex*" "$repo" && continue
    test -e /src/$repo.git || {
      git clone --bare $(htd git-remote $repo) /src/$repo.git
    }
  done
}


htd__git_list()
{
  test -n "$1" || set -- $(echo /src/*.git)
  for repo in $@
  do
    echo $repo
    git ls-remote $repo
  done
}

# List or look for files
# htd git-files [ REPO... -- ] GLOB...
htd__git_files()
{
  local pat="$(compile_glob $(lines_to_words $arguments.glob))"
  read_nix_style_file $arguments.repo | while read repo
  do
    cd $repo || continue
    # NOTE: only lists files at HEAD branch
    git ls-tree --full-tree -r HEAD | cut -d "	" -f 2 \
      | sed 's#^#'"$repo"':HEAD/#' | grep "$pat"
  done
}
htd_run__git_files=ia
htd_argsv__git_files=arg-groups-r
htd_arg_groups__git_files="repo glob"
htd_defargs_repo__git_files=/src/*.git


#
htd__git_grep()
{
  test -n "$1" || set -- $(echo /src/*.git)
  test -n "$grep" || grep=TODO
  {
    for repo in $@
    do
      ( cd $repo && echo $repo && git grep $grep $(git rev-list --all) )
    done
  } | less
}


htd__git_features()
{
  vc.sh list_local_branches
}

htd__features()
{
  (
    cd $1
    htd__git_features
  )
}

htd__gitflow_doc()
{
  test -n "$1" || set -- gitflow
  test -e "$1" || {
    for ext in .rst .txt
    do
      test -e $1$ext || continue
      set -- $1$ext; break
    done
  }
  test -e $1 || error no-gitflow-doc 2
  echo $1
}

htd_run__gitflow_check_doc=f
htd__gitflow_check_doc()
{
  test -n "$failed" || error failed 1
  test -z "$2" || error surplus-args 2
  set -- "$(htd__gitflow_doc "$1")"
  exec 6>$failed
  vc.sh list-all-branches | while read branch
  do
    match_grep_pattern_test "$branch" || return 12
    grep -q "\\s*$p_\\s*$" $1 || failed "$1: expected '$branch'"
  done
  exec 6<&-
  test -s "$failed" || rm "$failed"
  stderr ok "All branches found in '$1'"
}

htd_als__gitflow_check=gitflow-check-doc
htd_als__gitflow=gitflow-status

htd__gitflow_status()
{
  note "TODO: see gitflow-check"
  defs gitflow.txt | \
    tree_to_table  | \
    while read base branch
    do
      git cherry $base $branch | wc -l
    done
}


# indexing, cleaning

htd_name_precaution() {
  echo "$1" | grep -E '^[]\[{}\(\)A-Za-z0-9\.,!@#&%*?:'\''\+\ \/_-]*$' > /dev/null || return 1
}

htd__test_name()
{
  match_grep_pattern_test "$1" || return 1
  htd_name_precaution "$1" || return 1
  test "$cmd" = "test-name" && {
    echo 'name ok'
  }
  return 0
}

htd__find_empty()
{
  eval find . $find_ignores -o -size 0 -a -print
}

htd__find_largest()
{
  test -n "$1" || set -- 15
  # FIXME: find-ignores
  test -n "$find_ignores" || find_ignores="-not -iname .git "
  eval find . \\\( $find_ignores \\\) -a -size +${MIN_SIZE}c -a -print | head -n $1
}

htd__filesize()
{
  filesize "$1"
}

# XXX: a function to clean directories
# TODO: hark back to statusdir?
# TODO: notice deprecation marks
htd_run__check_files=
htd__check_files()
{
  log "Looking for unknown files.."

  pwd=$(pwd)
  cruft=$(setup_tmpd)/htd-$(echo $pwd|tr '/' '-')-cruft.list
  test ! -e "$cruft" || rm $cruft
  eval find . $find_ignores -o -print \
    | while read p
    do

      htd__test_name "$p" >> /dev/null || {
        warn "Unhandled characters: $p"
        continue
      }

      [ -L "$p" ] && {
        BE="$(dirname "$p")/$(readlink "$p")"
        [ -e "$BE" ] || {
          warn "Skip dead symlink"
          continue
        }
        SZ="$(filesize "$BE")"
      } || {
        SZ="$(filesize "$p")"
      }

      if test -d "$p" -a -n "$(htd__expand $p.{zip,tar{.gz,.bz2}})"
      then
        info "Skipping unpacked dir $p"
        for ck in ck sha1 md5
        do
          htd__ck_table_subtree $ck "$p" | while read p2
          do
            htd__ck_table $ck "$p2" > /dev/null && {
              #htd__ck_drop $ck "$p"
              warn "FIXME: Dropped $ck key for $p"
            }
          done
        done
        continue
      fi

      test "$SZ" -ge "$MIN_SIZE" || {
        warn "File too small: $p"
        echo $p >>$cruft
        continue
      }

    done

  test -s "$cruft" && {
    note "Cruft in $pwd: $(line_count $cruft) files"
  } || noop

}

htd_git_rename()
{
  $PREFIX/bin/matchbox.py rename "$1" "$2" |
  grep -Ev '^\s*(#.*|\s*)$' |
  while read file_old file_new
  do
    $cmd_pref git mv "$file_old" "$file_new"
  done
}

htd__rename_test()
{
  cmd_pref="echo"
  htd__rename $@
}

htd__rename()
{
  from_pattern="$1"
  to_pattern="$2"
  #$(echo $2 | sed 's/@\([A-Z0-9_]*\)/${\1}/g')
  shift 2
  test -z "$1" && {
    htd_git_rename "$from_pattern" "$to_pattern"
  } || {
    { for p in $@; do echo $p; done ; echo -e "\l"; } |
    htd_git_rename "$from_pattern" "$to_pattern"
  }
}


htd__ignore_names()
{
  test -n "$IGNORE_GLOBFILE" || error "IGNORE_GLOBFILE" 1
  lst list "$@"
}

htd_load__check_names="ignores"
htd__check_names()
{
  test -n "$IGNORE_GLOBFILE" || error "IGNORE_GLOBFILE" 1
  local find_ignores="$(find_ignores $IGNORE_GLOBFILE.names | lines_to_words)"
  test -z "$find_ignores" || find_ignores="-false $find_ignores -o"

  test -z "$1" && d="." || { d="$1"; shift 1; }
  test -z "$1" && valid_tags="" || valid_tags="$1"
  test "${d: -1:1}" = "/" && d="${d:0: -1}"

  test -z "$valid_tags" &&
    log "Looking for unmatched paths in $d" ||
    log "Validating $d, using valid patterns $valid_tags"

  {
    eval find $d " $find_ignores \( -type l -o -type f \) -a -print "
    echo "\l"
  } | matchbox.py check-names $valid_tags
}

htd__fix_names()
{
  local path_regex names_tables names_table
  req_cdir_arg "$1"
  match_grep_pattern_test "$path" || return 1
  path_regex="$p_"
  match_name_tables "$path"
  #
  htd_find_path_locals table.names $(pwd)
  names_tables=$path_locals
  for names_table in $names_tables
  do
    cat $names_table | grep -Ev '^(#.*|\s*)$' | while read match pattern tag
    do
      echo "$match" | grep '^'$path_regex > /dev/null || continue
      match_name_pattern "$pattern"
      for p in $match
      do
        echo "$p" | grep '^'"$grep_pattern"'$' >> /dev/null && {
          test -n "$tag" && {
            echo matched $tag $p
          } || {
            echo ok $p
          }
        } || test -n "$tag" || {
          echo mismatch $p
        }
      done
    done
  done
}

htd_host_arg()
{
  test -z "$1" && host=$1 || host=${hostname}
}

# TODO: pre-process file/metadata
htd__resolve()
{
  set --
}


# Commit staged files and push
htd_sp__pci="MSG [REMOTES]"
htd__pci()
{
  local git_add_f=""
  htd__pcia "$1" "$2" || return $?
}

# Commit tracked files and push to all remotes
htd_sp__pcia="MSG [REMOTES]"
htd__pcia()
{
  test -n "$1" || error "Commit message expected" 1

  test -n "$git_add_f" || local git_add_f=-u
  test -z "$git_add_f" -o " " = "$git_add_f" || {
    git add $git_add_f || return $?
  }

  git commit -m "$1" || return $?

  for remote in $(git remote)
  do
    test -n "$2" || set -- "$1" "--all"
    git push $2 $remote
  done
}


# Move path to archive path in htdocs cabinet
# XXX: see backup.
# $ archive [<prefix>]/[<datepath>]/[<id>] <refs>...
htd__archive()
{
  test -n "$1" || error "ID expected"
}


htd__file()
{
  file -s "$@"
}


htd_man_1__record="Retrieve, update or initalize record(s). "
htd_spc__record="record [PATH]"
htd__record()
{
  # TODO: Look at all services with .git or .meta/table
  # Else record locally
  test -e table.sha1 \
    && htd__ck_table sha1 "$1" \
    || {
      touch table.sha1
      htd__ck_update sha1 "$1"
    }
}


## Annex:

# Save refs (download locators if not present) to prefix,
# building a full path for each ref from the prefix+ids+filetags.
# $ save "[<prefix>/]<id>" <refs>...
# TODO: define global <prefix> and <id> to correspond with (sets of) path instances
# ie. lookup given prefix and id first, see if it exists.
# XXX: may have lookup lookup. Use -g to override.
# <prefix>
htd__save()
{
  htd__save_tags "$1"
  htd__save_url "$@"
}

htd__save_tags()
{
  set -- $@
  while test -n "$1"
  do
    tags.py get "$1" || tags.py insert "$1"
    shift 1
  done
}

htd__tags()
{
  test -n "$1" || set -- "*"
  tags.py find "$1"
}

htd__save_topics()
{
  test -n "$1" || error "Document expected" 1
  test -e "$1" || error "No such document $1" 1
  htd__tpaths "$1" | while read path
  do
    echo
  done
}


htd__save_url()
{
  annex=/Volumes/Simza/Downloads
  test "$(pwd -P)" = $annex || cd $annex

  test -n "$1" || error 'URL expected' 1
  test -n "$2" || {
    parseuri.py "$1"
    error "TODO: get filename"
  }
  test ! -e "$2" || error "File already exists: $2" 1
  git annex addurl "$1" --file "$2"
}

htd__save_ref()
{
  test -n "$1" || error "tags expected" 1
  tags="$1"

  shift 1
  for ref in "$@"
  do
    echo $ref
  done
}

htd__commit()
{
  echo -e
}

htd_man_1__run_names="List script names in package"
htd_run__run_names=f
htd__run_names()
{
  update_package
  jsotk.py keys -O lines .package.main scripts
}

htd_man_1__run_dir="List package script names and lines"
htd_run_dir__run_dir=f
htd__run_dir()
{
  htd__run_names | while read name
  do
    printf -- "$name\n"
    verbose_no_exec=1 htd__run $name
  done
}


htd_man_1__run="Run scripts from package"
htd_run__run=f
htd__run()
{
  test -n "$1" || set -- scripts

  # Update local package
  local metaf=
  update_package || return $?

  # With no arguments or name 'scripts' list script names,
  # Or no matching scripts returns 1
  jsotk.py -sq path --is-new $PACKMETA_JS_MAIN scripts/$1 && {
    test "$1" = "scripts" || {
      error "No obj scripts/$1" ; return 1; }

    trueish "$verbose_no_exec" && {
      echo jsotk.py keys -O lines $PACKMETA_JS_MAIN scripts
      return
    }

    # NOTE: default run
    htd__run_dir
    return $?
  }

  {
    jsotk.py path -O lines .package.main scripts/$1 || {
      error "error getting lines for '$1'"
      return 1
    }
  } | sponge | while read scriptline
  do
    not_trueish "$verbose_no_exec" || {
      printf -- "\t$scriptline\n"
      continue
    }
    info "Scriptline: '$scriptline'"
    ( eval "$scriptline" ) \
    &&
      continue || error "At line '$scriptline'" $?
  done

  # Execute script-lines
  (
    run_scriptname="$1"
    shift
    SCRIPTPATH=
    unset Build_Deps_Default_Paths
    package_sh_script "$run_scriptname" | while read scriptline
    do
      not_trueish "$verbose_no_exec" && {
        stderr info "Scriptline: '$scriptline'"
      } || {
        stderr note "Scriptline: '$scriptline'"
        continue
      }
      {
        eval "$scriptline"
      } &&
        continue || error "At line '$scriptline'" $?

      # NOTE: execute scriptline with args only once
      set --
    done
  )
}


htd_man_1__list_run="list lines for package script"
htd_list_run__list_run=f
htd__list_run()
{
  verbose_no_exec=1 \
    htd__run "$@"
}

htd__show_rules()
{
  htd_host_arg
  cat $htd_rules
}


# htdoc rules development documentation in htdocs:Dev/Shell/Rules.rst
# pick up with config:rules/comp.json and build `htd comp` aggregate metadata
# and update statemachines.
htd__period_status_files()
{
  touch -t $(date %H%M) $(statusdir.sh file period 1min)
  M=$(date +%M)
  _5M=$(( $(( $M / 5 )) * 5 ))
  touch -t $(date +%y%m%d%H${_5M}) $(statusdir.sh file period 5min)
  touch -t $(date +%y%m%d%H00) $(statusdir.sh file period hourly)
  H=$(date +%H)
  _3H=$(printf "%02d" $(( $(( $H / 3 )) * 3 )))
  touch -t $(date +%y%m%d${_3H}00) $(statusdir.sh file period 3hr)
  touch -t $(date +%y%m%d0000) $(statusdir.sh file period daily)
  ls -la $(statusdir.sh file period 3hr)
  ls -la $(statusdir.sh file period 5min)
  ls -la $(statusdir.sh file period hourly)
}

htd__run_rules()
{
  htd__period_status_files
  test -z "$DEBUG" \
    || fixed_table_hd_offsets $htd_rules CMD RT TARGETS CWD
  fixed_table_hd $htd_rules CMD RT TARGETS CWD | while read vars
  do
    eval local "$vars"
    #echo "CMD=$CMD RT=$RT TARGETS=$TARGETS"
    for target in $TARGETS
    do
      case "$target" in
        p:* )
            test -e "$(statusdir.sh file period ${target#*:})" && {
              echo "TODO 'cd $CWD;"$CMD"' for $target"
            } || error "Missing period for $target"
          ;;
        @* ) continue ;;
      esac
      # XXX: figuring out what/how rules to run
      htd__rule_target $target || note "TODO run '$CMD' for $target ($CWD)"
    done
  done
}

htd__edit_rules()
{
  $EDITOR $htd_rules $0
}

# arg: 1:target
# ret: 2: has run but failed or incomplete, 1: not run, 0: run was ok
htd__rule_target()
{
  case "$1" in

    # Period: assure exec once each period
    p:* )
      case "$1" in
        [smhdMY]* ) ;;
        [0-9]* )
          tdate=$(date +%y%m%d0000)
          ;;
      esac
      ;;

    # Domain
    d:* )
      sf=$(statusdir.sh file domain-network)
      test -e "$sf" || return 0
      test "d:$(cat $sf)" = "$1" || return 1
      ;;

    @* )
      sf=$(statusdir.sh file htd-rules-$1)
      test -s $sf && return 2 || test -e $sf || return 1
      ;;

  esac
}

htd__add_rule()
{
  set --
}

# parse path and annex metadata using given path

req_arg_pattern="Pattern format"
req_arg_path="Path"

htd__name_tags_test()
{
  match_name_vars $@
}

htd__name_tags()
{
  local pattern
  req_arg "$1" 'name-tags' 1 pattern && shift 1|| return 1
  req_arg "$1" 'name-tags' 2 path && path="$1" || return 1
  c=0
  test "${path: -1:1}" = "/" && path="${path:0: -1}"
  test -d "$path" && {
    eval find "$path $find_ignores -o \( -type f -o -type l \) -a -print" \
    | while read p
    do
      echo $p
      match_name_vars "$pattern" "$p" 2> /dev/null
      #c=$(( $c + 1 ))
      #echo $c
      #echo
    done
  } || {
    error "Req dir arg" 1
  }
}

htd__name_tags_all()
{
  req_arg "$1" 'name-tags-all' 1 path && path="$1" || return 1
  test "${path: -1:1}" = "/" && path="${path:0: -1}"
  test -d "$path" && {
    eval find "$path $find_ignores -o \( -type f -o -type l \) -a -print" \
    | while read p
    do
      match_names "$p"
    done
  } || {
    error "Req dir arg" 1
  }
}


htd_spc__update_checksums="update-checksums [TABLE_EXT]..."
htd__update_checksums()
{
  test -n "$1" || set -- ck sha1 md5
  failed=$(setup_tmpf .failed)
  test $(echo table.*) != "table.*" || error "No tables" 1
  for CK in $1
  do
    test -e table.$CK || continue
    note "Updating $CK table..."
    htd__ck_prune $CK || echo "htd:update:ck-prune:$CK" >>$failed
    htd__ck_clean $CK || echo "htd:update:ck-prune:$CK" >>$failed
    htd__ck_update $CK || echo "htd:update:ck-prune:$CK" >>$failed
    note "Update $CK table done"
  done
}


# Checksums

ck_arg_spec="[ck|sha1|md5]"
ck_arg()
{
  test -n "$ck_tab" || ck_tab=table
  test -n "$1"  && CK=$1  || CK=ck
  test -e $ck_tab.$CK || {
    error "First argument must be CK table extension, no such table: $ck_tab.$CK" 1
  }
  test -r $ck_tab.$CK || {
    error "Not readable: $ck_tab.$CK" 1
  }
  T_CK="$(echo $CK | tr 'a-z' 'A-Z')"
}

ck_write()
{
  ck_arg "$1"
  test -w $ck_tab.$CK || {
    error "Not writable: $ck_tab.$CK" 1
  }
}

htd_spc__ck="ck TAB [PATH|.]"
htd__ck()
{
  test -n "$1" || error "Need table to update" 1
  local table=$1 \
    ck_find_ignores="-name 'manifest.*' -prune \
      -o -name 'table.ck' -prune \
      -o -name 'table.sha1' -prune \
      -o -name 'table.md5' -prune"
  shift
  test -n "$1" || error "Need path to update table for " 1
  test -z "$find_ignores" \
    && find_ignores="$ck_find_ignores" \
    || find_ignores="$find_ignores -o $ck_find_ignores"

  while test -n "$1"
  do
    test -e "$1" || error "No such path to check: '$1'" 1
    test -d "$1" && {
      note "Adding dir '$1'"
      {
        eval find "$1" $find_ignores -o -type f -exec ${CK}sum "{}" + || return $?
      } > $table
      shift
      continue
    }
    test -f "$1" && {
      info "Adding one file '$1'"
      ${CK}sum "$1" > $table
      shift
      continue
    }
    note "Skipped '$1'"
    shift
  done
  note "Updated CK table '$table'"
}

htd__ck_init()
{
  test -n "$ck_tab" || ck_tab=table
  test -n "$1" || set -- ck "$@"
  test -n "$2" || set -- ck .
  touch $ck_tab.$1
  ck_arg "$1"
  shift 1
  htd__ck $ck_tab.$CK "$@"
}

htd__man_5_table_ck="Table of CK checksum, filesize and path"
htd__man_5_table_sha1="Table of SHA1 checksum and path"
htd__man_5_table_md5="Table of MD5 checksum and path"
# Either check table for path, or iterate all entries. Echoes checksum, two spaces and a path
htd__ck_table()
{
  var_isset ck_tab || local ck_tab=
  # table ext
  ck_arg "$1"
  test -n  "$1" && shift 1
  # second table ext
  test -n "$1" -a -e "$ck_tab.$CK.$1" && {
    S=$1; shift 1
  } || S=
  test -z "$1" && {
    {
      echo "#${T_CK}SUM  PATH"
      # run all entries
      cat $ck_tab.$CK$S | grep -Ev '^\s*(#.*|\s*)$' | \
      while read ckline_1 ckline_2 ckline_3
      do
        test "$CK" = "ck" && {
          cks=$ckline_1
          sz=$ckline_2
          p="$ckline_3"
        } || {
          cks=$ckline_1
          p="$ckline_2 $ckline_3"
        }
        echo "$cks  $p"
      done
    }
  } || {
    # look for single path
    htd_relative_path "$1"
    match_grep_pattern_test "$relpath" || return 1
    grep ".*\ \(\.\/\)\?$p_$" $ck_tab.$CK$S >> /dev/null && {
      grep ".*\ \(\.\/\)\?$p_$" $ck_tab.$CK$S
    } || {
      echo unknown
      return 1
    }
  }
}

htd_man_1__ck_table_subtree="Like ck-table, but this takes a partial path starting at the root level and returns the checksum records for files below that. "
htd_spc__ck_table_subtree="ck-tabke-subtree $ck_arg_spec <path>"
htd__ck_table_subtree()
{
  ck_arg "$1"
  shift 1
  test -n "$1" || return 1
  match_grep_pattern_test "$1" || return 1
  grep ".*\ $p_.*$" table.$CK | grep -v '^\(\s*\|#.*\)$' | \
  while read -a ckline
    do
      test "$CK" = "ck" && {
        cks=${ckline[@]::1}
        sz=${ckline[@]::1}
        p="${ckline[@]:2}"
      } || {
        cks=${ckline[@]::1}
        p="${ckline[@]:1}"
      }
      echo "$cks  $p"
    done
}

ck_update_file()
{
  ck_write "$CK"
  test -f "$1" || error "ck-update-file: Not a file '$1'" 1
  update_file="$1"
  # FIXME use test name again but must have some testcases
  # to verify because currently htd_name_precaution is a bit too strict
  # htd__test_name
  match_grep_pattern_test "$update_file" > /dev/null || {
    error "Skipped path with unhandled characters"
    return
  }
  test -r "$update_file" || {
    error "Skipped unreadable path '$update_file'"
    return
  }
  test -d "$update_file" && {
    error "Skipped directory path '$update_file'"
    return
  }
  test -L "$update_file" && {
    BE="$(dirname "$update_file")/$(readlink "$update_file")"
    test -e "$BE" || {
      error "Skip dead symlink"
      return
    }
    SZ="$(filesize "$BE")"
  } || {
    SZ="$(filesize "$update_file")"
  }
  test "$SZ" -ge "$MIN_SIZE" || {
    # XXX: trueish "$choice_ignore_small" \
    warn "File too small: $SZ"
    return
  }
  # test localname for SHA1 tag
  BN="$(basename "$update_file")"
  # XXX hardcoded to 40-char hexsums ie. sha1
  HAS_CKS="$(echo "$BN" | grep '\b[0-9a-f]\{40\}\b')"
  cks="$(echo "$BN" | grep '\b[0-9a-f]\{40\}\b' |
    sed 's/^.*\([0-9a-f]\{40\}\).*$/\1/g')"
  # FIXME: normalize relpath
  test "${update_file:0:2}" = "./" && update_file="${update_file:2}"
  #EXT="$(echo $BE)"

  test -n "$HAS_CKS" && {
    htd__ck_table "$CK" "$update_file" > /dev/null && {
      echo "path found"
    } || {
      grep "$cks" table.$CK > /dev/null && {
        echo "$CK duplicate found or cannot grep path"
        return
      }
      CKS=$(${CK}sum "$update_file" | cut -d' ' -f1)
      test "$cks" = "$CKS" || {
        error "${CK}sum $CKS does not match name $cks from $update_file"
        return
      }
      echo "$cks  $update_file" >> table.$CK
      echo "$cks added"
      return
    }
    return
  } || {
    # TODO prepare to rename, keep SHA1 hashtable
    htd__ck_table "$CK" "$update_file" > /dev/null && {
      note "Checksum present $update_file"
    } || {
      ${CK}sum "$update_file" >> table.$CK
      note "New checksum $update_file"
    }
  }
}

ck_update_find()
{
  info "Reading $T_CK, looking for files '$1'"
  find_p="$(strip_trail=1 normalize_relative "$1")"

  var_isset failed || {
    local failed_local=1 failed=$(setup_tmpf .failed)
    test ! -e $failed || rm $failed
  }

  local paths=$(setup_tmpf .$subcmd)
  test ! -e $paths || rm $paths

  ck_update_find_inner()
  {
    test -n "$find_ignores" && {
      eval find "$find_p" $find_ignores -o -type f -print || return $?
    } || {
      find "$find_p" -type f -print || return $?
    }
  }

  ck_update_find_inner > $paths || {
    echo "htd:$subcmd:find-inner" >>$failed
    test ! -e $paths || rm $paths
  }

  while read p
  do
    ck_update_file "$p" || echo "htd:$subcmd:$p" >>$failed
  done < $paths

  test -s "$failed" \
    && warn "Failures: $T_CK '$1', $(count_lines $failed) targets" \
    || stderr ok "$T_CK '$1', $(count_lines $paths) files"
  rm -rf $paths
  test -z "$failed" -o ! -e "$failed" || rm $failed
}


# find all files, check their names, size and checksum
htd__ck_update()
{
  test -n "$choice_ignore_small" || choice_ignore_small=1
  # XXX: htd_find_ignores
  ck_write "$1"
  shift 1
  test -n "$1" || set -- .
  while test -e "$1"
  do
    update_p="$1"
    shift 1
    test -n "$update_p" || error "empty argument" 1
    test -d "$update_p"  && {
      note "Checking $T_CK for dir '$update_p'"
      ck_update_find "$update_p" || return $?
      continue
    }
    test -f "$update_p" && {
      note "Checking $T_CK for '$update_p'"
      ck_update_file "$update_p" || return $?
      continue
    }
    test -L "$update_p" && {
      note "Checking $T_CK for symlink '$update_p'"
      ck_update_file "$update_p" || return 4
      continue
    }
    warn "Failed updating '$(pwd)/$update_p'"
  done
  test -z "$1" || error "Aborted on missing path '$1'" 1
}

htd__ck_drop()
{
  ck_write "$1"
  shift 1
  echo TODO ck_drop "$1"
  return
  req_arg "$1" 'ck-drop' 2 path || return 1
  match_grep_pattern_test "$1" || return 1
  cp table.$CK table.$CK.tmp
  cat table.$CK.tmp | grep "^.*$p_$" >> table.$CK.missing
  cat table.$CK.tmp | grep -v "^.*$p_$" > table.$CK
  rm table.$CK.tmp
}

htd_spc__ck_validate="ck-validate $ck_arg_spec [FILE..]"
htd__ck_validate()
{
  ck_arg "$1"
  shift 1
  test "$CK" = "ck" && {
    test -n "$1" && {
      for update_file in "$@"
      do
        htd__ck_table "$CK" "$update_file" | htd__cksum -
      done
    } || {
      htd__cksum table.$CK
    }
  } || {
    test -n "$1" && {
      for update_file in "$@"
      do
        htd__ck_table "$CK" "$update_file" | ${CK}sum -c -
      done
    } || {
      # Chec entire current $CK table
      ${CK}sum -c table.$CK
    }
  }
  stderr ok "Validated files from table.$CK"
}

# check file size and cksum
htd_spc__cksum="cksum [<table-file>]"
htd__cksum()
{
  test -n "$1"  && T=$1  || T=table.ck
  test -z "$2" || error "Surplus cksum arguments: '$2'" 1
  cat $T | while read cks sz p
  do
    SZ="$(filesize "$p")"
    test "$SZ" = "$sz" || { error "File-size mismatch on '$p'"; continue; }
    CKS="$(cksum "$p" | awk '{print $1}')"
    test "$CKS" = "$cks" || { error "Checksum mismatch on '$p'"; continue; }
    note "$p cks ok"
  done
}

# Drop non-existant paths from table, copy to .missing
htd__ck_prune()
{
  ck_write "$1"
  shift 1
  info "Looking for missing files in $CK table.."
  htd__ck_table $CK \
    | grep -Ev '^(#.*|\s*)$' \
    | while read cks p
  do
    test -e "$p" || {
      htd__ck_drop $CK "$p" \
        && note "TODO Dropped $CK key $cks for '$p'"
    }
  done
}

# Read checksums from *.{sha1,md5,ck}{,sum}
htd__ck_consolidate()
{
  htd_find_ignores
  test -n "$find_ignores" || error htd-$subcmd-find_ignores 1
  eval "find . $find_ignores -o -name '*.{sha1,md5,ck}{,sum}' -a \( -type f -o -type l \) " -print | while read p
  do
    echo "$p"
  done
}

# try to find files from .missing, or put them in .gone
# XXX: htd_man_1__ck_clean="Iterate checksum table, check for duplicates, normalize paths"
htd__ck_clean()
{
  ck_write "$1"
  shift 1
  test -s "table.$CK.missing" || {
    note "$T_CK.missing table does not exists, nothing to check"
    return
  }
  log "Looking for missing files from $CK table"/
  htd__ck_table $CK .missing | while read cks p
  do
    BN="$(basename "$p")"
    test -n "$BN" || continue
    NW=$(eval find ./ $find_ignores -o -iname '$BN' -a type f -a -print)
    test -n "$NW" && echo "$BN -> $NW"
  done
  echo 'TODO rewrite ck table path'
}

# TODO consolidate meta
htd__ck_metafile()
{
  [ -n "$1" ] && d=$1 || d=.
  CK=sha1
  eval find $d $find_ignores -o -iname \'*.meta\' -print \
  | while read metafile
  do
    ck_mf_p="$(dirname "$metafile")/$(basename "$metafile" .meta)"
    [ -e "$ck_mf_p" ] || {
      echo "missing source file $metafile: $ck_mf_p"
      continue
    }
    cks=$(rsr.py --show-sha1sum-hexdigest "$ck_mf_p" 2> /dev/null)
    htd__ck_table "$CK" "$ck_mf_p" > /dev/null && {
      log "$cks found"
    } || {
      CKS=$(${CK}sum "$ck_mf_p" | cut -d' ' -f1)
      #echo CKS=$CKS cks=$cks
      test "$cks" = "$CKS" && {
        log "$CKS ok $ck_mf_p"
      } || {
        error "Corrupt file: $ck_mf_p"
        continue
      }
      echo "$CKS  $ck_mf_p" >> table.$CK
    }

  done
}

# validate torrent
htd__ck_torrent()
{
  test -s "$1" || error "Not existent torrent arg 1: $1" 1
  test -f "$1" || error "Not a torrent file arg 1: $1" 1
  test -z "$2" -o -d "$2" || error "Missing dir arg" 1
  htwd=$(pwd)
  dir=$2
  test "$dir" != "." && pushd $2 > /dev/null
  test "${dir: -1:1}" = "/" && dir="${dir:0: -1}"
  log "In $dir, verify $1"

  #echo testing btshowmetainfo
  #btshowmetainfo $1

  node $PREFIX/bin/btinfo.js "$1" > $(setup_tmpd)/htd-ck-torrent.sh
  . $(setup_tmpd)/htd-ck-torrent.sh
  echo BTIH:$infoHash

  torrent-verify.py "$1" | while read line
  do
    test -e "${line}" && {
      echo $htwd/$dir/${line} ok
    }
  done
  test "$dir" != "." && popd > /dev/null
}


# xxx find corrupt files: .mp3
htd__mp3_validate()
{
  eval "find . $find_ignores -o -name "*.mp3" -a \( -type f -o -type l \) -print" \
  | while read p
  do
    SZ=$(filesize "$p")
    test -s "$p" || {
      error "Empty file $p"
      continue
    }
    mp3val "$p"
  done
}

htd__mux()
{
  test -n "$1" || set -- "docker-"
  test -n "$2" || set -- "$1" "dev"
  test -n "$3" || set -- "$1" "$2" "$(hostname -s)"

  note "tmuxinator start $1 $2 $3"
  tmuxinator start $1 $2 $3
}

htd__tmux_prive()
{
  test -n "$1" || set -- "*"
  cd
  case "$1" in init|"*" )
  tmux has-session -t Prive >/dev/null || {
    htd__tmux_init Prive
    tmux send-keys -t Prive:1 "cd;simza test" enter
  }
  tmux list-windows -t Prive | grep -q HtD || {
    tmux new-window -t Prive -n HtD
    tmux send-keys -t Prive:HtD "cd ~/htdocs/; htd today $HTD_JRNL;git st" enter
    tmux send-keys -t Prive:HtD "git add -u;git add dev/ personal/*.rst
    $HTD_JRNL/2*.rst sysadmin/*.rst *.rst;git st" enter
    note "Initialized 'HtD' window"
  }
  tmux list-windows -t Prive | grep -q '\ conf' || {
    tmux new-window -t Prive -n conf
    tmux send-keys -t Prive:conf "cd ~/.conf;git st" enter
    note "Initialized 'conf' window"
  }
  tmux list-windows -t Prive | grep -q Bin || {
    tmux new-window -t Prive -n Bin
    tmux send-keys -t Prive:Bin "cd ~/bin;git st" enter
    note "Initialized 'Bin' window"
  }
  ;; esac

  case "$1" in ino )
  tmux list-windows -t Prive | grep -q Ino || {
    tmux new-window -t Prive -n Ino
    tmux send-keys -t Prive:Ino "cd ~/project/arduino-docs;git st" enter
    note "Initialized 'Ino' window"
  }
  ;; esac

  case "$1" in eagle )
  tmux list-windows -t Prive | grep -q EAGLE || {
    tmux new-window -t Prive -n EAGLE
    tmux send-keys -t Prive:EAGLE "cd ~/project/Eagle-mpe;git st" enter
    note "Initialized 'EAGLE' window"
  }
  ;; esac
  #tmux list-windows -t Prive | grep -q Loci || {
  #  tmux new-window -t Prive -n Loci
  #  tmux send-keys -t Prive:Loci "cd ~/project/node-loci;git st" enter
  #}
  case "$1" in sf )
  tmux list-windows -t Prive | grep -q Sf || {
    tmux new-window -t Prive -n Sf
    tmux send-keys -t Prive:Sf "cd ~/project/node-sitefile;git st" enter
    note "Initialized SiteFile [Sf] window"
  }
  ;; esac

  case "$1" in docs )
  tmux list-windows -t Prive | grep -q Docs || {
    tmux new-window -t Prive -n Docs
    tmux send-keys -t Prive:Docs "cd ~/Documents/;git st" enter
    note "Initialized Documents window"
  }
  ;; esac
}

htd__tmux_work()
{
  test -n "$1" || set -- "*"
  cd ~/work/brix

  ### Make sure Work session is registered with tmux server

  case "$1" in init|"*" )

  tmux has-session -t Work >/dev/null || htd__tmux_init Work bash
  sleep 2

  # Make sure Log window is on and first window (swapping some windows if
  # needed, maybe better way it to start server by hand instead of usign new-session?)

  tmux list-windows -t Work | grep -q Log || {
    # No log, new session, need to clean up first window, add one first to keep session
    tmux new-window -t Work -n temporary
    tmux kill-window -t Work:1
  }
  sleep 1

  tmux list-windows -t Work | grep -q '1:\ Log' || {
    tmux new-window -t Work -n Log
    tmux send-keys -t Work:Log "cd ~/work/brix/;htd today log" enter
    tmux send-keys -t Work:Log "(cd log;git add -u;git add 20*.rst; git st)" enter
  }
  sleep 1

  tmux list-windows -t Work | grep -q temporary && {
    tmux kill-window -t Work:temporary
  } || noop

  ;; esac


  ### Add other windows

  case "$1" in tree|"*" )
  tmux list-windows -t Work | grep -q Tree || {
    tmux new-window -t Work -n Tree
    tmux send-keys -t Work:Tree "cd ~/work/brix/" enter "make status" enter
    note "Initialized Tree window"
  }
  ;; esac
  case "$1" in cln|"*" )
  tmux list-windows -t Work | grep -q Cleaning || {
    tmux new-window -t Work -n TreeCln
    tmux send-keys -t Work:TreeCln "cd /Volumes/Simza/WorkCleaning/brix" enter "make status" enter
    note "Initialized TreeCln window"
  }
  ;; esac
  case "$1" in jenkins )
      htd tmux-winit Work Jnk ~/work/brix/Jenkins \
        "(cd jenkins-ci-config && git fetch --all && git status); (cd userContent && git fetch --all && git status)"
  ;; esac
  case "$1" in dev-doc )
      htd tmux-winit Work DvD ~/work/brix/tree/dev-doc
  ;; esac
  case "$1" in skel* )
      htd tmux-winit Work Skl ~/work/brix/tree/project-skeleton-ng
  ;; esac
  case "$1" in mango|"*" )
      htd tmux-winit Work MngB /Volumes/Simza/WorkCleaning/brix/tree/mango-builds
  ;; esac

  case "$1" in studio|"*" )
  tmux list-windows -t Work | grep -q BrxStd || {
    tmux new-window -t Work -n BrxStd
    tmux send-keys -t Work:BrxStd "cd /Volumes/Simza/WorkCleaning/brix/tree/brixcloud-studio-testing" enter "git st" enter
    note "Initialized BrxStd window"
  }
  tmux list-windows -t Work | grep -q BrxStdT || {
    tmux new-window -t Work -n BrxStdT
    tmux send-keys -t Work:BrxStdT "cd /Volumes/Simza/WorkCleaning/brix/tree/brixcloud-studio-testing2;ls -la" enter
    note "Initialized BrxStdT window"
  }
  tmux list-windows -t Work | grep -q BrxStdSkl || {
    tmux new-window -t Work -n BrxStdSkl
    tmux send-keys -t Work:BrxStdSkl "cd ~/work/brix/tree/brixcloud-studio-skeleton" enter "git st" enter
    note "Initialized BrxStdSkl window"
  }
  ;; esac


  ### Clients

  case "$1" in sw|stein*|steinweg )
  tmux list-windows -t Work | grep -q Sw || {
    tmux new-window -t Work -n Sw
    # TODO
    tmux send-keys -t Work:Sw "cd /Volumes/Simza/work/brix/tree/steinweg" enter "git st" enter
    note "Initialized Sw window"
  }
  ;; esac
}

htd__tmux_srv()
{
  cd /srv
  tmux has-session -t Srv >/dev/null || {
    htd__tmux_init Srv
    tmux send-keys -t Srv:bash "cd ~/.conf; ./script/update.sh" enter
  }
  tmux list-windows -t Srv | grep -q HtD-Sf || {
    tmux new-window -t Srv -n HtD-Sf
    tmux send-keys -t Srv:HtD-Sf "cd ~/htdocs/; sitefile" enter
  }
  tmux list-windows -t Srv | grep -q BrX-Sf || {
    tmux new-window -t Srv -n BrX-Sf
    tmux send-keys -t Srv:BrX-Sf "cd ~/work/brix/; sitefile" enter
  }
  tmux list-windows -t Srv | grep -q X-Tw || {
    tmux new-window -t Srv -n X-Tw
    tmux send-keys -t Srv:X-Tw "cd ~/project/x-tiddlywiki; tiddlywiki x-tiddlywiki --server" enter
  }
  tmux list-windows -t Srv | grep -q Loci || {
    tmux new-window -t Srv -n Loci
    tmux send-keys -t Srv:Loci "cd ~/project/node-loci; npm start" enter
  }
}


# htd tmux-winit SESSION WINDOW DIR CMD
htd__tmux_winit()
{
  ## Parse args
  test -n "$1" || error "Session <arg1> required" 1
  test -n "$2" || error "Window <arg2> required" 1
  test -n "$3" || {
    # set working dir
    case "$1" in
      Work )
        set -- "$1" "$2" "~/work/brix/tree/$2" ;;
      Prive )
        set -- "$1" "$2" "~/project/$2" ;;
      * )
        error "Cannot setup working-dir for window '$1:$2'" 1 ;;
    esac
  }
  test -d "$3" || error "Expected <arg3> to be directory '$3'" 1
  test -n "$4" || {
    set -- "$1" "$2" "$3" "git fetch --all && status"
  }

  tmux list-windows -t $1 | grep -q $2 && {
    note "Window '$1:$2' already initialized"
  } || {
    tmux new-window -t $1 -n $2
    tmux send-keys -t $1:$2 "cd $3" enter "$4" enter
    note "Initialized '$1:$2' window"
  }
}

htd__tmux_init()
{
  test -n "$1" || error "session name required" 1
  test -n "$2" || set -- "$1" "bash"
  #'reattach-to-user-namespace -l /bin/bash'"
  test -z "$3" || error "surplus arguments: '$3'" 1

  test -n "$TMUX_TMPDIR" || TMUX_TMPDIR=/opt/tmux-socket
  mkdir -vp $TMUX_TMPDIR
  out=$(setup_tmpd)/htd-tmux-init-$$

  tmux has-session -t "$1" >/dev/null 2>&1 && {
    logger "Session $1 exists" 0
    note "Session $1 exists" 0
  } || {
    tmux new-session -dP -s "$1" "$2" && {
    #>/dev/null 2>&1 && {
      note "started new session '$1'"
      logger "started new session '$1'"
    } || {
      logger "Failed starting session ($?) ($out):"
      printf "Cat ($out) "
    }
    #rm $out
  }
}

# Start tmux, tmuxinator or htd-tmux with given names
htd__tmux()
{
  while test -n "$1"
  do
    func="htd__tmux_$(echo $1 | tr 'A-Z' 'a-z')"
    fname="$(echo "$1" | tr 'A-Z' 'a-z')"

    tmux has-session -t $1 >/dev/null 2>&1 && {
      info "Session $1 exists"
      shift
      continue
    }

    func_exists "$func" && {

      # Look for init subcmd to setup windows
      note "Starting htd TMUX $1 (tmux-$fname) init"
      try_exec_func "$func" || return $?

    } || {
      test -e "$HOME/.conf/tmuxinator/$fname.yml" && {
        note "Starting tmuxinator '$1' config"
        htd__mux $1 &
      } || {
        note "Starting htd-tmux '$1' config"
        htd__tmux_init $1
      }
    }
    shift
  done

  test -n "$TMUX" || tmux attach
}

htd__reader_update()
{
  cd /Volumes/READER

  for remote in .git/refs/remotes/*
  do
    name="$(basename "$remote")"
    newer_than "$remote" _1HOUR && {
      info "Remote $name is up-to-date"
    } || {
      note "Remote $name is too old, syncing"
      git annex sync $name && continue || error "sync failed"
    }
  done

  note "Removing dead symlinks (annex content elsewhere), for PRS software"
  find ./ -type l | while read l
  do
      test -e "$l" || rm "$l"
  done
}

htd_man_1__test="Project test in HTDIR"
htd__test()
{
  test -n "$HTDIR" || error HTDIR 1
  cd $HTDIR || error HTDIR 2
  projectdir.sh test
}
htd_als___t=test


htd_man_1__edit_test="edit-tests"
htd__edit_test()
{
  $EDITOR ./test/*-spec.bats
}
htd_als___T=edit-test


htd_man_1__inventory="All inventories"
htd__inventory()
{
  test -e "$HTDIR/personal/inventory/$1.rst" && {
    set -- "personal/inventory/$1.rst" "$@"
  } || {
    set -- "personal/inventory/main.rst" "$@"
  }
  htd_rst_doc_create_update $1
  htd_edit_and_update $@
}
htd_als__inv=inventory

htd_man_1__inventory_elecronics="Electr(on)ics inventory"
htd__inventory_electronics()
{
  set -- "personal/inventory/components.rst" \
      "personal/inventory/modules.rst" \
      "personal/inventory/hardware.rst" "$@"
  htd_rst_doc_create_update $1
  htd_edit_and_update $@
}
htd_als__inv_elec=inventory-electronics


htd__disk_id()
{
  test -n "$1" || error "Disk expected" 1
  test -e "$1" || error "Disk path expected '$1'" 1
  disk_id "$1" || return $?
}

htd__disk_model()
{
  test -n "$1" || error "Disk expected" 1
  test -e "$1" || error "Disk path expected '$1'" 1
  disk_id "$1" || return $?
}

htd__disk_size()
{
  test -n "$1" || error "Disk expected" 1
  test -e "$1" || error "Disk path expected '$1'" 1
  disk_size "$1" || return $?
}

htd__disk_tabletype()
{
  test -n "$1" || error "Disk expected" 1
  test -e "$1" || error "Disk path expected '$1'" 1
  disk_tabletype "$1" || return $?
}

htd__disks()
{
  test -n "$rst2xml" || error "rst2xml required" 1
  sudo which parted 1>/dev/null && parted=$(sudo which parted) \
    || warn "No parted"
  test -n "$parted" || error "parted required" 1
  DISKS=/dev/sd[a-e]
  for disk in $DISKS
  do
    echo "$disk $(htd disk-id $disk)"
    echo "  :table-type: $(htd disk-tabletype $disk)"
    echo "  :size: $(htd disk-size $disk)"
    echo "  :model: $(htd disk-model $disk)"
    echo ""
    for dp in $disk[0-9]*
    do
        pn="$(echo $dp | sed 's/^.*\([0-9]*\)/\1/')"
        ps="$(sudo parted $disk -s print | grep '^\ '$pn | awk '{print $4}')"
        pt="$(sudo parted $disk -s print | grep '^\ '$pn | awk '{print $5}')"
        fs="$(sudo parted $disk -s print | grep '^\ '$pn | awk '{print $6}')"
        echo "  - $dp $pt $(echo $(find_partition_ids $dp)) $ps $fs"
    done
    echo
  done
  echo
}


htd__create_ram_disk()
{
  test -n "$1" || set -- "RAM disk" "$2"
  test -n "$2" || set -- "$1" 32
  test -z "$3" || error "Surplus arguments '$3'" 1

  note "Creating/updating RAM disk '$1' ($2 MB)"
  create_ram_disk "$1" "$2" || return
}


htd__realpath()
{
  f_realpath "$@"
}

htd__normalize_relative()
{
  normalize_relative "$1"
}

# Get document part using xpath
# XXX: relies on rST/XML.
htd__getx()
{
  test -n "$1" || error "Document expected" 1
  test -e "$1" || error "No such document <$1>" 1
  test -n "$2" || error "XPath expr expected" 1

  test -n "$3" || set "$1" "$2" "$(htd__getxl $1)"

  xmllint --xpath "$2" "$3"
  rm "$3"
}

# Get x-lang file for arg1
htd__getxl()
{
  fnmatch '*.xml' $1 && set -- "$1" "$1"
  fnmatch '*.rst' $1 && {
    test -n "$2" || set -- "$1" "$(setup_tmpd)/$(basename "$1" .rst).xml"
    $rst2xml $1 > "$2"
    echo $2
  }
  test -e "$2" || error "Need XML repr. for doc '$1'" 1
}

# List topic paths (nested dl terms) in document paths
htd_load__tpaths="xsl"
htd__tpaths()
{
  local verbosity=5
  test -n "$1" || error "At least one document expected" 1
  test -n "$print_src" || local print_src=
  test -n "$xsl_ver" || xsl_ver=1
  info "xsl_ver=$xsl_ver"

  while test -n "$1"
  do
    test -e "$1" || {
      warn "No file <$1>, skipped"
      shift 1
      continue
    }
    path= rel_leaf= root= xml=$(htd__getxl $1)

    # Read multi-leaf paths, and split it up into relative leafs

    {
      case "$xsl_ver" in
        1 ) htd__xproc "$xml" $scriptpath/rst-terms2path.xsl ;;
        2 ) htd__xproc2 "$xml" $scriptpath/rst-terms2path-2.xsl ;;
        * ) error "xsl-ver '$xsl_ver'" 1 ;;
      esac
    } | grep -Ev '^(#.*|\s*)$' \
      | sed 's/\([^\.]\)\/\.\./\1\
../g' \
      | grep -v '^\.[\.\/]*$' \
      | while read rel_leaf
    do

      # Assemble each leaf path onto its root, and normalize
      echo "$rel_leaf" | grep -q '^\.\.\/' && {
        path="$(normalize_relative "$path/$rel_leaf")"
      } || {
        path="$(normalize_relative "$rel_leaf")"
      }

      test -n "$print_src" \
        && echo "$1 $path" \
        || echo "$path"

    done

    test ! -e "$xml" || rm "$xml"

    unset path rel_leaf root
    shift 1
  done
}
htd_vars__tpaths="path rel_leaf root xml"

htd__tpath_refs()
{
  test -n "$1" || error "document expected" 1
  test -e "$1" || error "no such document '$1'" 1
}

htd_load__tpath_raw="xsl"
htd__tpath_raw()
{
  test -n "$1" || error "document expected" 1
  test -e "$1" || error "no such document '$1'" 1
  test -n "$xsl_ver" || xsl_ver=1
  info "xsl_ver=$xsl_ver"
  local xml=$(htd__getxl $1)

  case "$xsl_ver" in
    1 ) htd__xproc "$xml" $scriptpath/rst-terms2path.xsl ;;
    2 ) htd__xproc2 "$xml" $scriptpath/rst-terms2path-2.xsl ;;
    * ) error "xsl-ver '$xsl_ver'" 1 ;;
  esac
}

# Process XML using XSLT
htd__xproc()
{
  {
    fnmatch '<* *>' "$2" && {

      xsltproc --novalid - $1 <<EOM
$2
EOM
    } || {
      xsltproc --novalid $2 $1
    }
  # remove XML prolog:
  } | tail -n +2 | grep -Ev '^(#.*|\s*)$'
}

htd__xproc2()
{
  {
    fnmatch '<* *>' "$2" && {

      saxon - $1 <<EOM
$2
EOM
    } || {
      test -e "$1" || error "no file for saxon: '$1'" 1
      saxon $1 $2
    }
  # remove XML prolog:
  } | cut -c39-
}


# TODO: Append definition term to doc
htd__dl_init()
{
  test -n "$1" || error "Document expected" 1
  test -e "$1" || error "Document expected: <$1>" 1
  test -n "$2" || error "Term expected" 1
  htd getx '//*/term[text()="'$2'"]' "$1"
}

# TODO: Add list item beneath definition term
htd__dl_append()
{
  echo
}

# XXX: host-disks hacky hacking one day, see wishlist above
list_host_disks()
{
  test -e sysadmin/$hostname.rst || error "Expected sysadm hostdoc" 1

  htd getx sysadmin/$hostname.rst \
    "//*/term[text()='Disk']/ancestor::definition_list_item/definition/definition_list" \
    > $(setup_tmpd)/$hostname-disks.xml

  test -s "$(setup_tmpd)/$hostname-disks.xml" || {
    rm "$(setup_tmpd)/$hostname-disks.xml"
    return
  }

  {
    xsltproc - $(setup_tmpd)/$hostname-disks.xml <<EOM
<xsl:stylesheet version="1.0" xmlns:xsl="http://www.w3.org/1999/XSL/Transform">
<xsl:template match="definition_list_item">
<xsl:value-of select="term"/> .
</xsl:template>
</xsl:stylesheet>
EOM
  # remove XML prolog:
  } | tail -n +2 | grep -Ev '^(#.*|\s*)$'
}

htd__check_disks()
{
  test -d $HTDIR || error "No HTDIR" 1
  cd $HTDIR
  list_host_disks | while read label path id eol
  do
    test -e "$path" && {
      echo "Path for $label OK"
      xmllint --xpath \
          "//definition_list/definition_list_item/definition/bullet_list/list_item[contains(paragraph,'"$path"')]/ancestor::bullet_list" \
          $(setup_tmpd)/$hostname-disks.xml > $(setup_tmpd)/$hostname-disk.xml;
      {
      xsltproc - $(setup_tmpd)/$hostname-disk.xml <<EOM
<xsl:stylesheet version="1.0" xmlns:xsl="http://www.w3.org/1999/XSL/Transform">
<xsl:template match="//bullet_list/list_item">
<xsl:value-of select="paragraph/text()"/> .
</xsl:template>
</xsl:stylesheet>
EOM
  # remove XML prolog:
  } | tail -n +2 | grep -Ev '^(#.*|\s*)$' \
      || {
        warn "failed $?"
      }
    } || {
      error "Missing $label $id <$path>" 1
    }
  done
  rm $(setup_tmpd)/$hostname-disk.xml
}


# Setup X tcp socket for VS1 containers
htd__xtcp()
{
  socat TCP-LISTEN:6000,reuseaddr,fork UNIX-CLIENT:\"$DISPLAY\"
}


gcal_tab=~/.conf/google/cals.tab
htd__man_5_cals_tab="List of Google calendar IDs"

gcal_tab_ids()
{
  if test -n "$1"
  then
    cat $gcal_tab
  else
    grep '\<'$1 $gcal_tab
  fi
}

# List current and upcoming events
htd__events()
{
  test -n "$2" || set -- "$1" "days=3"

  cat ~/.conf/google/cals.tab | while read calId summary
  do
    note "Upcoming events for '$summary'"
    gcal.py list-upcoming 7 $calId "$2" 2>/dev/null
  done
}

# List upcoming events at any date
htd__upcoming_events()
{
  gcal_tab_ids "$1" | while read calId summary
  do
    note "Upcoming events for '$summary'"
    gcal.py list-upcoming 7 $calId 2>/dev/null
  done
}

# List events of +/- 1day
htd__current_events()
{
  test -n "$2" || set -- "$1" "days=1" "$3" "$4"
  test -n "$3" || set -- "$1" "$2" "days=1" "$4"
  test -n "$4" || set -- "$1" "$2" "$3" "7"

  gcal_tab_ids "$1" | while read calId summary
    do
      note "Current events ($2/$3) for '$summary' ($calId)"
      gcal.py happening-now $7 $calId "$1" "$2" 2>/dev/null
    done
}


htd__active()
{
  test -n "$tdata_fmt" && {
    note "Listing files active in '$@'"
  } || {
    tdata_fmt=$TODAY
    note "Listing files active today in '$@'"
  }
  tdate=$(date "$1")

  test -n "$2" || set -- "$1" "$(pwd -P)"
  shift
  test -n "$tdate" || error "formatting date" 1
  touch -t $tdate $(statusdir.sh file recent-paths)
  htd__recent_paths "$@"
}


htd_man_1__current_paths='
  List open paths under given or current dir. Dumps lsof without cmd, pid etc.'
htd__current_paths()
{
  test -n "$1" || set -- "$(pwd -P)"
  note "Listing open paths under $1"
  # print only pid and path name, keep name
  lsof -Fn +D $1 | tail -n +2 | grep -v '^p' | cut -c2- | sort -u
}
htd_als__lsof=current-paths


htd_man_1__open_paths='Create list of open files, and show differences on
  subsequent calls. '
htd_spc__open_paths="open-paths ['\\<sh\\|bash\\>']"
htd__open_paths()
{
  test -n "$1" || set -- '\<sh\|bash\>'

  export lsof=$(statusdir.sh assert-dir htd/open-paths.lsof)
  export lsof_paths=$lsof.paths
  export lsof_paths_ck=$lsof_paths.sha1

  # Get open paths for user, bound to CWD of processes, and with 15 COMMAND chars
  # But keep only non-root, and sh or bash lines, throttle update of cached file
  # by 10s period.
  {
    test -e "$lsof" && newer_than $lsof 10
  } || {
    lsof +c 15 -u $(whoami) -a -d cwd \
      | eval "grep '^$1'" \
      | grep -v '\ \/$' \
      | tail -n +2 >$lsof

    debug "Updated $lsof"

    info "Commands: $(echo $(
        sed 's/\ .*$//' $lsof | sort -u
      ))"

    sed 's/^.*\ //' $lsof | sort -u > $lsof_paths.tmp
  }

  test -e $lsof_paths_ck && {
    sha1sum -c $lsof_paths_ck >/dev/null
  } || {
    sha1sum "$lsof.paths.tmp" > $lsof_paths_ck
    test ! -e $lsof_paths && {
      note "Initialized $(
        sed 's/^\([^\ ]*\).*/\1/g' $lsof_paths_ck | cut -c-11
      )"
    } || {
      note "Updated $(
        sed 's/^\([^\ ]*\).*/\1/g' $lsof_paths_ck | cut -c-11
      )"
      git diff --color $lsof_paths $lsof_paths.tmp | tail -n +6 \
        1>&2
      # XXX: clean-me
      #diff $lsof_paths $lsof_paths.tmp | vim -R -
      #cdiff $lsof_paths $lsof_paths.tmp
    }
    cp $lsof.paths.tmp $lsof.paths
  }

  note "Paths:"
  cat $lsof_paths
}
htd_als__of=open-paths
htd_als__open_files=open-paths


# List paths newer than recent-paths setting
htd__recent_paths()
{
  test -n "$1" || set -- "$(pwd -P)"
  note "Listing active paths under $1"
  dateref=$(statusdir.sh file recent-paths)
  find $1 -newer $dateref
}


# Scan for bashims in given file or current dir
htd__spc__bashisms="bashism [DIR]"
htd__bashisms()
{
  test -n "$1" || set -- "."
  f=-srI

  # Scan for bash redirect
  grep $f '\&>' "$@" && {
    note "Bash extension found: '&>...' is a shortcut for '>... 2>&1'"
  }

  # Scan for bash, ksh etc. keyword
  grep $f '\<source\|declare\|typeset\>' "$@" && {
    note "Bash extension found"
  }
}

htd__clean()
{
  test -n "$UCONFDIR" || error "No UCONFDIR" 1
  test -e $UCONFDIR/script/clean.sh || error "No clean script in UCONFDIR" 1
  $UCONFDIR/script/clean.sh || return $?
}

htd_man_1__clean_unpacked="Given archive, look for existing, possibly unpacked (direct) neighbour dirs
interactively delete, compare, or skip"
htd__clean_unpacked()
{
  test -n "$1" || error "archive" 1
  test -n "$2" || set -- "$1" "$(dirname "$1")"

  test -e "$1" && {
    test -f "$1" || error "not a file: '$1'" 1
  } || {
    test -h "$1" && {
      warn "skipped broken symlink '$1'"
      return 1
    } || error "No archive '$1'" 2
  }

  local  archive="$(basename "$1")"

  set -- "$(cd "$(dirname "$1")"; pwd -P)/$archive" "$2"

  local oldwd="$(pwd)" dirty="$(statusdir.sh file htd clean-unpacked)"
  test ! -e "$dirty" || rm "$dirty"

  cd "$2"

  # scenario 1: look for archive-basename as dir (ie. unzip, some friendlier unpackers--Darwin, Gnome maybe)
  local dir="$(archive_basename "$1")"
  test -d "$dir" && {

    archive_update "$1" && {
      test -z "$dry_run" && {
        error "rm -rf $dir"
      } || {
        note "looking clean $1 (** DRY-RUN **) "
      }
    } || {
      note "Possibly unpacked basedir '$dir' (from $1)"
      touch $dirty
    }

  } || {

    # scenario 2: look root dirs from archive
    archive_list "$1" crc32 name | sed 's/^\([^\/]*\).*$/\1/' | sort -u | while read path
    do
      test -e "$path" && {
        note "Possibly unpacked path '$path' (from $1)"
        touch $dirty
      } || {
        debug "No dir $(pwd)/$path"
        continue
      }
    done

  }

  cd "$oldwd"

  test ! -e "$dirty" && stderr ok "$1" || warn "Crufty $1" 1
}

# given archive, note unpacked files
htd__note_unpacked()
{
  test -n "$1" || error "archive" 1
  test -n "$2" || set -- "$1" "$(dirname "$1")"

  test -e "$1" && {
    test -f "$1" || error "not a file: '$1'" 1
  } || {
    test -h "$1" && {
      warn "skipped broken symlink '$1'"
      return 1
    } || error "No archive '$1'" 2
  }

  local  archive="$(basename "$1")"

  set -- "$(cd "$(dirname "$1")"; pwd -P)/$archive" "$2"

  local oldwd="$(pwd)" dirty="$(statusdir.sh file htd note-unpacked)"
  test ! -e "$dirty" || rm "$dirty"

  cd "$2"

  archive_list "$1" | while read file
  do
    test -e "$file" && {
      note "Found unpacked $file (from $archive)"
      touch $dirty
      # check for changes?
    } || {
      debug "No file $(pwd)/$file"
      continue
    }
  done

  cd "$oldwd"

  test ! -e "$dirty" && info "OK $1" || warn "Crufty $1" 1
}

# given archive, note files out of sync
htd__test_unpacked()
{
  test -n "$1" || error "archive" 1
  test -n "$2" || set -- "$1" "$(dirname "$1")"

  test -e "$1" && {
    test -f "$1" || error "not a file: '$1'" 1
  } || {
    test -h "$1" && {
      warn "skipped broken symlink '$1'"
      return 1
    } || error "No archive '$1'" 2
  }

  local  archive="$(basename "$1")"

  set -- "$(cd "$(dirname "$1")"; pwd -P)/$archive" "$2"

  local oldwd="$(pwd)" dirty=
  #"$(statusdir.sh file htd test-unpacked)"
  #test ! -e "$dirty" || rm "$dirty"

  cd "$2"

  archive_update "$1" || dirty=1

  cd $oldwd

  test -z "$dirty" && info "OK $1" || warn "Crufty $1" 1
}

archive_basename()
{
  test -n "$1" || error "archive-basename:1" 1
  case "$1" in
    *.zip )
      basename "$1" .zip
      ;;
    * )
      error "archive-basename ext: '$1'" 1
  esac
}

archive_list()
{
  test -n "$1" || error "archive-list:1" 1
  case "$1" in
    *.zip )
      unzip -l "$1" | read_unzip_list
      ;;
    * )
      error "archive-list ext: '$1'" 1
  esac
}

read_unzip_list()
{
  oldIFS=$IFS
  IFS=\n
  read
  read headers
  # see fixed_table_hd_offset; dont bother with 0-index correction here
  # XXX: expr still helps to strip ws even with IFS off..? [Darwin]
  offset=$(( $(printf "$headers" | sed 's/^\(.*\)'Name'.*/\1/g' | wc -c) - 0 ))
  read
  while read line
  do
    case $line in " "*---- | " "*[0-9]*" files" ) continue ;; esac
    #printf "line='$line'\n"
    printf -- "%s" "$line" | cut -c$offset-
  done
  IFS=$oldIFS
}

# TODO: update/list files out of sync
# XXX: best way seems to use CRC (from -lv output at Darwin)
archive_update()
{
  test -n "$1" || error "archive-update:1" 1
  local dirty="$(statusdir.sh file htd archive-update dirty)" \
    cnt="$(statusdir.sh file htd archive-update count)"
  test ! -e "$dirty" || rm "$dirty"
  printf 0 >$cnt
  case "$1" in
    *.zip )
      unzip -lv "$1" | read_unzip_verbose_list | while read line
      do
        length="$(echo $line | cut -d\  -f 1)"
        crc32="$(echo  $line | cut -d\  -f 7)"
        name="$(echo   $line | cut -d\  -f 8)"
        debug "$name ($crc32, $length)"
        printf $(( $(cat "$cnt") + 1 )) > $cnt
        test -e "$name" && {
          test "$(filesize "$name")" = "$length" && {
            test "$(crc32 "$name")" = "$crc32" && {
              #stderr ok "$name ($1)"
              continue
            } || {
              warn "CRC-error $name ($1)" 1
              touch $dirty
            }
          } || {
            warn "Size mismatch $name ($1)" 1
            touch $dirty
          }
        }
      done
      ;;
    * )
      error "archive-list ect: '$1'" 1
  esac
  c=$(cat $cnt)
  test ! -e "$dirty" && stderr ok "$1 ($c files)" || warn "Dirty $1" 1
}

htd__archive_list()
{
  archive_verbose_list "$@"
}

# echo request fields
archive_verbose_list()
{
  test -n "$1" || error "archive-verbose-list:1" 1
  local f=$1
  shift 1
  test -n "$1" || error "archive-verbose-list:fields" 1
  fields="$(for x in "$@"; do printf "\$$x "; done)"
  case "$f" in

    *.zip )
        unzip -lv "$f" | read_unzip_verbose_list | while read line
        do
          length="$(echo $line | cut -d\  -f 1)"
          method="$(echo $line | cut -d\  -f 2)"
          size="$(echo $line   | cut -d\  -f 3)"
          ratio="$(echo $line  | cut -d\  -f 4)"
          date="$(echo  $line  | cut -d\  -f 5)"
          time="$(echo  $line  | cut -d\  -f 6)"
          crc32="$(echo  $line | cut -d\  -f 7)"
          name="$(echo   $line | cut -d\  -f 8)"
          eval echo $fields
        done
      ;;

    * )
      error "archive-list ect: '$1'" 1

  esac
}

read_unzip_verbose_list()
{
  oldIFS=$IFS
  IFS=\n
  read # 'Archive:'
  read hds # headers
  read cols # separator
  # Lines
  while read line
  do
    fnmatch *----* "$line" && break || noop
    printf -- "%s\n" "$line"
  done
  read cols # separator
  read # totals
  IFS=$oldIFS
}


htd__export_docker_env()
{
  launchctl setenv DOCKER_HOST $DOCKER_HOST
  launchctl setenv DOCKER_MACHINE_NAME $DOCKER_MACHINE_NAME
  launchctl setenv DOCKER_TLS_VERIFY $DOCKER_TLS_VERIFY
  launchctl setenv DOCKER_CERT_PATH $DOCKER_CERT_PATH
  note "OK"
}

htd__import_docker_env()
{
  echo DOCKER_HOST=$(launchctl getenv DOCKER_HOST)
  echo DOCKER_MACHINE_NAME=$(launchctl getenv DOCKER_MACHINE_NAME)
  echo DOCKER_TLS_VERIFY=$(launchctl getenv DOCKER_TLS_VERIFY)
  echo DOCKER_CERT_PATH=$(launchctl getenv DOCKER_CERT_PATH)
}


# Forced color output commands

htd__git_status()
{
  git -c color.status=always status
}

htd__ls()
{
  case "$uname" in
    Darwin )
      CLICOLOR_FORCE=1 ls $1
    ;;
    Linux )
      ls --colors=yes $1
    ;;
  esac
}


# XXX: to-html of vim-syntax highlited files. But what about ANSI in and out?
# Also, this does not seem to take colorscheme values?
# There is also ANSI HTML Adapter https://github.com/theZiz/aha
# Below is not ideal, maybe AHA is better.
#
# FIXME: pstree-color is perhaps not returning valid escapes, as 2html.vim chokes
htd__colorize()
{
  test -n "$1" || set -- "-"

  case "$1" in

    - )

      set -- $(setup_tmpd)/htd-vim-colorize.out
      #{ cat - > $1 ; }
      #exec 0<&-

      #  -R -E -s  \
      vim \
        -c "syntax on" \
        -c "AnsiEsc" \
        -c "w! $1" \
        -c "let g:html_no_progress=1" \
        -c "let g:html_number_lines = 0" \
        -c "let g:html_use_css = 1" \
        -c "let g:use_xhtml = 1" \
        -c "let g:html_use_encoding = 'utf-8'" \
        -c "TOhtml" \
        -c "wqa!" \
        -

      open $1.xhtml

      rm $(setup_tmpd)/htd-vim-colorize* $(setup_tmpd)/.htd-vim-colorize*
      ;;

    * )
      test -e "$1" || error "no file $1" 1
      #  -E -s \
      # -R -E -s  \
      vim \
        -c "syntax on" \
        -c "AnsiEsc" \
        -c "let g:html_no_progress=1" \
        -c "let g:html_number_lines = 0" \
        -c "let g:html_use_css = 1" \
        -c "let g:use_xhtml = 1" \
        -c "let g:html_use_encoding = 'utf-8'" \
        -c "TOhtml" \
        -c "wqa!" \
        "$1"
      open $1.xhtml
      rm $1.xhtml
      ;;

  esac
}



htd__say()
{
  lang=$1
  shift
  test -n "$s" || s=f
  case "$lang" in
    uk )
      case "$s" in m )
          say -v Daniel "$@" ;;
        f )
          say -v Kate "$@" ;;
      esac;;
    us )
      case "$s" in m )
          say -v Alex "$@" ;;
        f )
          say -v Samantha "$@" ;;
      esac;;
    dutch | nl )
      case "$s" in m )
          say -v Xander "$@" ;;
        f )
          say -v Claire "$@" ;;
      esac;;
    japanese | jp )
      case "$s" in m )
          say -v Otoya "$@" ;;
        f )
          say -v Kyoko "$@" ;;
      esac;;
    chinese | cn | sc )
      say -v Ting-Ting "$@" ;;
    hong-kong | sar | tc )
      say -v Sin-ji "$@" ;;
  esac
}


htd__domain()
{
  note "Domain User ID: "$(cat $(statusdir.sh file domain-identity))
  note "Domain Net ID: "$(cat $(statusdir.sh file domain-network))
}


htd__init_project()
{
  local new= confirm=

  cd ~/project

  # Check for existing git, or commit everything to new repo
  test -d "$1/.git" || {
    test -d "$1" && note "Found existing dir" || new=1
    mkdir -vp $1
    ( cd $1; git init ; git add -u; git st )
    test -n "$new" || read -p "Commit everything to git? [yN] " -n 1 confirm
    test -n "$new" -o "$confirm" = "y" || {
      warn "Cancelled commit in $1" 1
    }
    ( cd $1; git commit "Automatic project commit"; htd git-init-remote $1 )
  }

  # Let projectdir handle rest
  test -e "$1" && {
    pd init "$@"
  } || {
    pd add "$@"
  }
}


# Sort filesizes into histogram, print percentage of bins filled
# Bin edges are fixed
htd__filesize_hist()
{
  test -n "$1" || -- set "/"
  log "Getting filesizes in '$@'"
  sudo find $1 -type f 2>/dev/null | ./filesize-frequency.py
  return $?
}



# exit succesfully after receiving 4 replies
htd__ping()
{
  case "$uname" in

    Darwin )
        ping -ot 4 $1 || return $?
      ;;

    Linux )
        ping -c 4 $1
      ;;

  esac
}


# Count depth (excluding root)
htd__path_depth()
{
  test -n "$1" || error arg-1-path-expected 1

  while test -n "$1"
  do
    path="$(htd__normalize_relative "$1")"
    #note "Depth for path $path"
    # Count dashes (except the trailing one)
    depth=$(echo $path | tr '/' ' ' | count_words)
    # Remove root.
    echo $(( $depth - 1 ))
    shift
  done
}
htd_als__depth=path-depth


# (Re)init service volume links (srv-init) and get (repo) state (srv-stat)
htd__srv()
{
  htd__srv_init "$@" || return $?
  htd__srv_stat "$@" || return $?
}

# Update disk volume catalog, and reinitialize service links
htd__srv_init()
{
  disk check-all || {
    disk update-all || {
      error "Failed updating volumes catalog and links"
    }
  }
}


# Volumes for services

htd_man_1__srv_list="Print info to stdout, one line per symlink in /srv"
htd_spc__srv_list="src-list [DOT]"
htd__srv_list()
{
  test -n "$verbosity" -a $verbosity -gt 5 || verbosity=6
  set -- "$(echo $1 | str_upper)"
  case "$1" in
      DOT )  echo "digraph htd__srv_list { rankdir=RL; ";; esac
  for srv in /srv/*
  do
    test -h $srv || continue
    target="$(readlink $srv)"
    name="$(basename "$srv" -local)"
    test -e "$target" || {
      stderr warn "Missing path '$target'"
      continue
    }
    depth=$(htd__path_depth "$target")

    case "$1" in
        DOT )
            NAME=$(mkvid "$name"; echo $vid)
            TRGT=$(mkvid "$target"; echo $vid)
            case "$target" in
              /mnt*|/media*|/Volumes* )

                  echo "$TRGT [ shape=box3d, label=\"$(basename "$target")\" ] ; // 1.1"
                  echo "$NAME [ shape=tab, label=\"$name\" ] ;"

                  DISK="$(cd /srv; disk id $target)"

                  #TRGT_P=$(mkvid "$(dirname "$target")";echo $vid)
                  #echo "$TRGT_P [ shape=plaintext, label=\"$(dirname $target)\" ] ;"

                  test -z "$DISK" ||
                    echo "$TRGT -> $DISK ; // 1.3 "
                  echo "$NAME -> $TRGT ; "
                  #[ label=\"$(basename "$target")\" ] ;"
                ;;
              *)
                  echo "$NAME [ shape=folder, label=\"$name\"] ; // 2.1"
                  test $depth -eq 1 && {

                    TRGT_P=$(mkvid "$(dirname "$target")";echo $vid)
                    echo "$TRGT_P [ label=\"$(dirname "$target")\" ] ;"
                    echo "$NAME -> $TRGT_P [ label=\"$(basename "$target")\" ] ;"
                    info "Chain link '$name' to $target"
                  } || {
                    test $depth -gt 1 && {
                      warn "Deep link '$name' to $target"
                    } || {
                      info "Neighbour link '$name' to $target"
                      echo "$NAME -> $TRGT [style=dotted] ;"
                    }
                  } ;;
            esac
          #        echo "$(mkvid "$(dirname "$target")";echo $vid) [ label=\"$(dirname $target)\" ]; "
          #        echo "$(mkvid "$(dirname "$target")";echo $vid) -> $TRGT ; "
          ;;
    esac

    case "$target" in
      /mnt*|/media*|/Volumes* )
          note "Volume link '$name' to $target" ;;
      * )
          test $depth -eq 1 && {
            info "Chain link '$name' to $target"
          } || {
            test $depth -gt 1 && {
              warn "Deep link '$name' to $target"
            } || {
              info "Neighbour link '$name' to $target"
            }
          } ;;

    esac
  done
  case "$1" in
      DOT )  echo "} // digraph htd__srv_list";; esac
}

htd__srv_stat()
{
  # TODO: manage volume's repo's
  note "TODO: Local volume repositories all OK"
}


# Update volume repositories
htd__srv_update()
{
  note "TODO: Local volume repositories all updated"
}

# services list
SRVS="archive archive-old scm-git src annex www-data cabinet htdocs shared \
  docker"
# TODO: use service names from disk catalog

# Go over local disk to see if volume links are there
htd__ls_volumes()
{
  disk list-local | while read disk
  do
    prefix=$(disk prefix $disk 2>/dev/null)
    test -n "$prefix" || error "No prefix found" 1

    disk_index=$(disk info $disk disk_index 2>/dev/null)

    for volume in /mnt/$prefix-*
    do
      test -e $volume/.volumes.sh || continue
      . $volume/.volumes.sh
      test "$volumes_main_prefix" = "$prefix" \
        || error "Prefix mismatch '$volumes_main_prefix' != '$prefix' ($volume)" 1


      # Check for unknown service roots
      test -n "$volumes_main_export_all" || volumes_main_export_all=1
      trueish "$volumes_main_export_all" && {
        echo $volume/* | tr ' ' '\n' | while read vroot
        do
          test -n "$vroot" || continue
          vdir=$(basename "$vroot")
          echo $SRVS lost+found | grep -q $vdir || {
            warn "Unkown volume dir $vdir" 1
          }
        done
      }

      # TODO: check all aliases, and all mapping aliases
      test -n "$volumes_main_aliases__1" \
        || error "Expected one aliases ($volume)"

      test -e "/srv/$volumes_main_aliases__1"  || {
        error "Missing volume alias '$volumes_main_aliases__1' ($volume)" 1
      }

      # Go over known services
      for srv in $SRVS
      do
        test -e $volume/$srv && {

          t=/srv/$srv-local
          test -e "$t" || warn "Missing $t ($volume/$srv)"

          # TODO: check for global id as well
          #t=/srv/$srv-${disk_idx}-${part_idx}-$(hostname -s)-$domain
          #test -e "$t" || warn "Missing $t ($volume/$srv)"

        }
      done

      note "Volumes OK: $disk_index.$part_index $volume"

      unset srv \
        volumes_main_prefix \
        volumes_main_aliases__1 \
        volumes_main_export_all

    done

    note "Disk OK: $disk_index. $prefix"

  done
}

htd__munin_ls()
{
  test -n "$1" || set -- $DCKR_VOL/munin/db
  tail -n +2 $1/datafile | while read dataline
  do
    hostgroup=$(echo $dataline | cut -d ':' -f 1)
    echo hostgroup=$hostgroup
    #grep -F $hostgroup $1/datafile \
    #  | sed 's#/^.*:##'

  done
  #| sort -u
}

htd__munin_ls_hosts()
{
  test -n "$1" || set -- $DCKR_VOL/munin/db
  tail -n +2 $1/datafile | while read dataline
  do echo $dataline | cut -d ':' -f 1
  done | sort -u
}

htd__munin_archive()
{
  echo TODO $subcmd
# archive selected plugins, sensor names
# 4 sets MIN/MAX/AVG values per attr:
# 5min (day), 30min (week), 2h (month), 24h (year)
# File: munin-log/2016/[02/[01/]]<group>.log.gz
# Line: <ts> <plugin> <attr>=<min>,<max>,<avg> [<attr>.*=<v>]*
#
# One backup every day, two every week, three every month, and all four very year.
}

htd__munin_merge()
{
  echo TODO $subcmd
  # rename/merge selected plugins, sensor names
}

htd__munin_volumes()
{
  local local_dckr_vol=/srv/$(readlink /srv/docker-local)

  echo /srv/docker-*-*/munin | words_to_lines | while read munin_volume
  do
    test "$local_dckr_vol/munin" = "$munin_volume" && {
      echo $munin_volume [local]
    } || {
      echo $munin_volume
    }
  done
}

# Remove stale databases, check index
htd__munin_check()
{
  test -n "$1" || set -- "$DCKR_VOL/munin/db"
  while read dataline
  do
    group="$(echo $dataline | cut -d ':' -f 1)"
    propline="$(echo $dataline | cut -d ':' -f 2)"
    plugin="$(echo $propline | sed 's/\.[a-zA-Z0-9_-]*\ .*$//' )"
    attr="$(echo $propline | sed 's/^.*\.\([a-zA-Z0-9_-]*\)\ .*$/\1/' )"
    value="$(echo $propline | sed 's/^[^\ ]*\ //' )"

  done < $4/datafile
}

htd__munin_export()
{
  test -n "$1" || {
    test -n "$4" || set -- "" "$2" "$3" $DCKR_VOL/munin/db
    test -n "$3" || set -- "" "$2" g "$4" # or d
    test -n "$2" || set -- "" vs1/vs1-users-X-$2.rrd "$3" "$4"
    set -- "$4/$2-$3.rrd" "$2" "$3" "$4"
  }

  while read dataline
  do
    group="$(echo $dataline | cut -d ':' -f 1)"
    propline="$(echo $dataline | cut -d ':' -f 2)"
    plugin="$(echo $propline | sed 's/\.[a-zA-Z0-9_-]*\ .*$//' )"
    attr="$(echo $propline | sed 's/^.*\.\([a-zA-Z0-9_-]*\)\ .*$/\1/' )"
    value="$(echo $propline | sed 's/^[^\ ]*\ //' )"

    echo $dataline | grep -q 'title' && {
      echo "$group\t$plugin\t$attr\t$value"
    }
    echo $dataline | grep -qv '\.graph_' && {
      echo "$group\t$plugin\t$attr\t$value"
      #echo ls -la $4/$(echo $group | tr ';' '/')-$plugin-$(echo $attr | tr '.' '_' )-*.rrd
    }
  done < $4/datafile
# | column -tc 3 -s '\t'

  return

  # ds-name for munin is always 42?
  #"/srv/docker-local/munin-old-2015/db"

  for name in $4/*/*.rrd
  do
    basename "$name" .rrd
    continue
    rrdtool xport --json \
            DEF:out1=$1:42:AVERAGE \
            XPORT:out1:"42"
  done
}



htd__count_lines()
{
  count_lines "$@"
}


htd__find_broken_symlinks()
{
  find . -type l -xtype l
}

htd__find_skip_broken_symlinks()
{
  find . -type l -exec file {} + | grep -v broken
}


htd_man_1__uuid="Print a UUID line to stdout"
htd_spc__uuid="uuid"
htd__uuid()
{
  get_uuid
}


htd_man_1__finfo="Touch document metadata for htdocs:$HTDIR"
htd_spc__finfo="finfo DIR"
htd__finfo()
{
  for dir in $@
  do
    finfo.py --recurse --documents --env htdocs=HTDIR $dir \
      || return $?
  done
}


# Initialize local backup annex and symlinks
htd__init_backup_repo()
{
  test ! -e "/srv/backup-local" \
    || error "Local backup annex exists (/srv/backup-local)" 1

  test -n "$1" && {
    test -d "$1" || error "Dir expected" 1
  } || {
    test -d /srv/annex-local/ && set -- "/srv/annex-local"
    info "Using local annex folder for annex-backup checkout"
  }

  git clone $(htd git-remote annex-backup) $1/backup \
    && info "Cloned annex-backup into $1/backup" || return $?
  ln -s $1/backup /srv/backup-local \
    && info "Initialized backup-local symlink ($1/backup)" || return $?

  note "Initialized local backup annex ($1/backup)"
}


# Copy/move all given file args to backup repo
htd__backup()
{
  local act= bu_act_lbl= bu_act=

  test -n "$choice_keep" || choice_keep=1 # TODO

  trueish "$dry_run" && {
    note "Doing dry-run of $# files.."
    act="echo '*** DRY-RUN ***'"
  } || act=''

  trueish "$choice_keep" && {
    note "Copying $# files to backup.."; bu_act=cp; bu_act_lbl=Copy
  } || {
    note "Moving $# files to backup.."; bu_act=mv; bu_act_lbl=Move
  }

  local srcpaths="$(for arg in $@
    do
      test -f "$arg" || warn "Missing or not a file for backup: '$arg'" 1
      realpath "$arg"
    done )"

  test -d "/srv/backup-local" || error "Unknown error" $?
  (
    cd /srv/backup-local
    git diff --quiet --exit-code \
      || error "Changed in local backup repo" 1
  )

  # Created dest path from given path but replace path elements
  local destpath= prefix=
  while test -n "$1"
  do
    trueish "$no_cabinet" || {
      prefix=$(date_flags="-r $(filemtime $1)" date_fmt "" %Y/%m/%d-)
    }
    destpath="$prefix$(echo "$1" | tr '/' '-')"
    dirname=$(dirname $destpath)
    test -z "$dirname" || {
      test -d /srv/backup-local/$dirname || mkdir -vp /srv/backup-local/$dirname
    }
    test ! -e /srv/backup-local/$destpath \
      || error "File $destpath already exist" 1
    eval $act $bu_act $1 /srv/backup-local/$destpath \
      && note "$bu_act_lbl '$1' to backup" \
      || warn "$bu_act_lbl '$1' failed" 1
    shift
    test ! -d /srv/backup-local/.git || {
      ( cd /srv/backup-local
        eval $act git annex add $destpath || error "Failed adding files to annex" $?
      )
    }
  done

  cd /srv/backup-local

  test ! -d .git || {
    {
      test -n "$msg" || msg="Backed up files at '$hostname':\n\n$srcpaths"
      trueish "$dry_run" && {
        eval $act git ci -m \\\"\"$msg\"\\\"
      } || {
        echo "$msg" | git ci -F -
      }
    } \
      || error "Failed making backup commit" $?

    test ! -d "/srv/backup-local/.git/annex" || {
      eval $act git annex sync \
        || error "Annex sync failed" $?
    }
  }
}
htd_run__backup=iAoP
htd_pre__backup=htd_backup_prereq
htd_argsv__backup=htd_backup_args
htd_optsv__backup=htd_backup_opts


htd_man_1__pack_create="Create archive for dir with ck manifest"
htd_man_1__pack_verify="Verify archive with manifest, see that all files in dir are there"
htd_man_1__pack_check="Check file (w. checksum) TODO:dir with archive manifest"
htd_run__pack=i
htd__pack()
{
  test -n "$2" || set -- "$1" . "$3"

  test -n "$3" || set -- "$1" "$2" "$(basename "$(realpath "$2")")"
  fnmatch "*.tar.*" "$3" || set -- "$1" "$2" "$3.tar.lzma"

  case "$1" in

    create )
  test -d "$2" || error "No such dir '$2'" 3
        test ! -e "$3" || error "archive already exists '$3'" 3
        test -n "$CK" || CK=sha1
        test "$CK" != "ck" || error "TODO ck sums" 1
        local tab=manifest.$CK
        test ! -e $tab || error "Manifest exists: $tab" 1
        htd__ck $tab "$2"
        find $2 -iname '*.tar*' >>$skipped
        info "Creating archive from '$2'"
        tar --exclude '*.tar*' --lzma -cvf "$3" $tab "$2" \
          2>&1 | grep '^a\ ' | sed 's/^a\ /htd:'"$subcmd"':create:added/g' \
          >> $passed
        rm $tab
        note "Created archive '$3' from '$2'"
      ;;

    verify ) # verify files are present and cataloged. No checksumming.
        tar -tf "$3" >/dev/null \
          && htd_passed "Archive checked '$3'" \
          || error "Error in archive '$3'" 1
        tar -xf "$3" manifest.* || error "No manifest(s) in archive '$3'" 1
        local ck_tab=manifest
        test -e $ck_tab.sha1 || error $ck_tab.sha1-expected 1
        # FIXME: iterate files instead
        while read checksum path
        do
          htd__ck_table sha1 "$path" \
            || echo "htd:$subcmd:verify:$check" >>$failed
        done < $ck_tab.sha1
        rm $ck_tab.*
      ;;

    #validate )
    #    test "$CK" = "ck" && {
    #      htd__cksum table.$CK
    #    } || {
    #      ${CK}sum -c table.$CK
    #    }
    #  ;;

    check ) # lookup and compare checksum from manifest
  test -f "$2" || error "No such file '$2'" 3
        tar -xf "$3" manifest.* || error "No manifest(s) in archive '$3'" 1
        local ck_tab=manifest
        # find...
        sha1sum="$(sha1sum "$2" | awk '{print $1}')"
        test "$sha1sum" = "$(htd__ck_table sha1 "$2" | cut -f 1 -d ' ')" \
          && echo "htd:$subcmd:$2" >>$passed \
          || echo "htd:$subcmd:$2" >>$failed
      ;;

    add )
        echo TODO
      ;;

  esac

  test ! -s "$skipped" || {
    note "Skipped files: $(cat $skipped)"
    return 1
  }
}


htd_backup_prereq()
{
  test -e /srv/backup-local || {
    trueish "$choice_interactive" && {
      test -n "$choice_confirm" || confirm "Create local backup annex repo?"
      trueish "$choice_confirm" && {
        htd init-backup-repo || return $?
      }
    } || {
      error "Expected backup dir" 1
    }
  }
}

htd_backup_args()
{
  test -n "$*" || error "Nothing to backup?" 1
  opt_args "$@"
}

htd_backup_opts()
{
  set -- "$(cat $options)"
  while test -n "$1"
  do
    case "$1" in
      --archive* )
        ;;
      --tags-append* )
        ;;
      --node-base )
        ;;
      --add-base )
        ;;
      --no-cabinet )
        ;;
      * )
          htd_options_v "$1"
        ;;
    esac
    shift
  done
}



# List GNU PG keys
htd__gpg()
{
  gpg -K --keyid-format long --with-colons --with-fingerprint
}

# Export GNU-PG keys in ASCII format
htd__gpg_export()
{
  gpg --export --armor $1
}


htd__bdd_args()
{
  for x in *.py *.sh test/*.feature test/bootstrap/*.php
  do
    printf -- "-w $x "
  done
}

htd__bdd()
{
  test -n "$1" && {
    set -- test/$1.feature
    nodemon -x "./vendor/.bin/behat $1" \
      --format=progress \
      -C $(htd__bdd_args)
  } || {
    set -- test/
    nodemon -x "./vendor/.bin/behat $1" \
      --format=progress \
      $(htd__bdd_args)
  }
}


htd__clean_osx()
{
  sys_confirm "Continue to remove Caches? [yes/no]" || return 1
  (
    sudo rm -rf ~/Library/Caches/*/*
    #/Library/Caches/*/*
  ) && stderr ok "Deleted contents of {~,}/Library/Caches" ||
    error "Failure removing contents of {~,}/Library/Caches"
}


# util

htd_rst_doc_create_update()
{
  test -n "$1" || error htd-rst-doc-create-update 12
  test -s "$1" && {
    updated=":\1pdated: $(date +%Y-%m-%d)"
    grep -qi '^\:[Uu]pdated\:.*$' $1 && {
      sed -i.bak 's/^\:\([Uu]\)pdated\:.*$/'"$updated"'/g' $1
    } || {
      warn "Cannot update 'updated' field."
    }
  } || {
    test -n "$2" || set -- "$1" "$(basename "$(dirname "$(realpath "$1")")")"
    echo "$2" > $1
    echo "$2" | tr -C '\n' '=' >> $1
    echo ":created: $(date +%Y-%m-%d)" >> $1
    echo ":updated: $(date +%Y-%m-%d)" >> $1
    echo  >> $1
    export cksum="$(md5sum $1 | cut -f 1 -d ' ')"
    export cksums="$cksums $cksum"
  }
}


htd_edit_and_update()
{
  test -e "$1" || error htd-edit-and-update-file 1

  vim "$@" || return $?

  new_ck="$(md5sum "$1" | cut -f 1 -d ' ')"
  test "$cksum" = "$new_ck" && {
    # Remove unchanged generated file, if not added to git
    git ls-files --error-unmatch $1 >/dev/null 2>&1 || {
      rm "$1"
      note "Removed unchanged generated file ($1)"
    }
  } || {
    git add "$1"
  }
}




# Script main functions

htd_main()
{
  local scriptname=htd base=$(basename "$0" .sh) \
    scriptpath="$(cd "$(dirname "$0")"; pwd -P)" \
    subcmd= failed=

  htd_init || exit $?

  case "$base" in

    $scriptname )

        test -n "$1" || set -- main-doc

        #htd_lib || exit $?
        #run_subcmd "$@" || exit $?

        htd_lib "$@" || error htd-lib $?

        try_subcmd "$@" && {

          #record_env_keys htd-subcmd htd-env

          box_src_lib htd || error "box-src-lib htd" 1
          shift 1

          htd_load "$@" || error "htd-load" $?

          var_isset verbosity || local verbosity=5

          test -z "$arguments" -o ! -s "$arguments" || {
            info "Setting $(count_lines $arguments) args to '$subcmd' from IO"
            set -f; set -- $(cat $arguments | lines_to_words) ; set +f
          }

          $subcmd_func "$@" || r=$?
          htd_unload || r=$?
          exit $r
        }
      ;;

    * )
        error "not a frontend for $base ($scriptname)" 1
      ;;

  esac
}

htd_init_etc()
{
  test ! -e etc/htd || echo etc
  test ! -e $(dirname $0)/etc/htd || echo $(dirname $0)/etc
  #XXX: test ! -e .conf || echo .conf
  #test ! -e $UCONFDIR/htd || echo $UCONFDIR
  info "Set htd-etc to '$*'"
}

# FIXME: Pre-bootstrap init
htd_init()
{
  # XXX test -n "$SCRIPTPATH" , does $0 in init.sh alway work?
  test -n "$scriptpath"
  export SCRIPTPATH=$scriptpath
  . $scriptpath/util.sh load-ext
  lib_load
  . $scriptpath/box.init.sh
  box_run_sh_test
  lib_load htd meta box date doc table disk remote ignores package
  # -- htd box init sentinel --
}

htd_lib()
{
  local __load_lib=1
  . $scriptpath/match.sh load-ext
  lib_load list ignores
  # -- htd box lib sentinel --
  set --
}

# Use hyphen to ignore source exec in login shell
case "$0" in "" ) ;; "-"* ) ;; * )
  # Ignore 'load-ext' sub-command
  test -z "$__load_lib" || set -- "load-ext"
  case "$1" in load-ext ) ;; * )
    htd_main "$@"
  ;; esac
;; esac

# Id: script-mpe/0.0.3-dev htd.sh
