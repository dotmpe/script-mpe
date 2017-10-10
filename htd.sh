#!/bin/bash

#FIXME: !/bin/sh
#
# Htdocs: work in progress 'daily' shell scripts
#

htd_src=$_
test -z "$__load_lib" || set -- "load-ext"

set -o posix
set -e

version=0.0.4-dev # script-mpe


htd__inputs="arguments prefixes options"
htd__outputs="passed skipped error failed"

htd_load()
{
  # -- htd box load insert sentinel --
  default_env EDITOR vim || debug "Using EDITOR '$EDITOR'"
  test -n "$TODOTXT_EDITOR" || {
    test -x "$(which todotxt-machine)" &&
      TODOTXT_EDITOR=todotxt-machine || TODOTXT_EDITOR=$EDITOR
  }
  test -n "$DOC_EXT" || DOC_EXT=.rst
  test -n "$DOC_EXTS" || DOC_EXTS=".rst .md .txt"
  test -n "$TASK_EXT" || TASK_EXT="ttxtm"
  test -n "$TASK_EXTS" || TASK_EXTS=".ttxtm .list .txt"
  default_env CWD "$(pwd)" || debug "Using CWD '$CWD'"
  default_env UCONFDIR "$HOME/.conf/" || debug "Using UCONFDIR '$UCONFDIR'"
  default_env TMPDIR "/tmp/" || debug "Using TMPDIR '$TMPDIR'"
  default_env HTDIR "$HOME/public_html" || debug "Using HTDIR '$HTDIR'"
  test -n "$FIRSTTAB" || export FIRSTTAB=50
  test -n "$LOG" -a -x "$LOG" || export LOG=$scriptpath/log.sh
  default_env Script-Etc "$( htd_init_etc|head -n 1 )" ||
    debug "Using Script-Etc '$SCRIPT_ETC'"
  test -n "$HTD_TOOLSFILE" || HTD_TOOLSFILE="$CWD"/tools.yml
  test -n "$HTD_TOOLSDIR" || HTD_TOOLSDIR=$HOME/.htd-tools
  default_env Jrnl-Dir "personal/journal" || debug "Using Jrnl-Dir '$JRNL_DIR'"
  default_env Htd-GIT-Remote "$HTD_GIT_REMOTE" ||
    debug "Using Htd-GIT-Remote name '$HTD_GIT_REMOTE'"
  default_env Htd-Ext ~/htdocs:~/bin ||
    debug "Using Htd-Ext dirs '$HTD_EXT'"
  default_env Htd-ServTab $UCONFDIR/htd-services.tab ||
    debug "Using Htd-ServTab table file '$HTD_SERVTAB'"
  default_env Cabinet-Dir "cabinet" || debug "Using Cabinet-Dir '$CABINET_DIR'"

  test -d "$HTD_TOOLSDIR/bin" || mkdir -p $HTD_TOOLSDIR/bin
  test -d "$HTD_TOOLSDIR/cellar" || mkdir -p $HTD_TOOLSDIR/cellar

  default_env Htd-BuildDir .build
  test -d "$HTD_BUILDDIR" || mkdir -p $HTD_BUILDDIR
  export B=$HTD_BUILDDIR

  # Set default env to differentiate tmux server sockets based on, this allows
  # distict CS env for tmux sessions
  default_env Htd-TMux-Env "hostname CS"
  # Initial session/window vars
  default_env Htd-TMux-Default-Session "Htd"
  default_env Htd-TMux-Default-Cmd "$SHELL"
  default_env Htd-TMux-Default-Window "$(basename $SHELL)"
  default_env Couch-URL http://sandbox-3:5984

  projectdirs="$(echo ~/project ~/work/*/tree)"

  go_to_directory .projects.yaml && {
    cd "$CWD"
    # $go_to_before
    #PROJECT="$(basename $(pwd))"
  } || {
    cd "$CWD"
  }

  # XXX:
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

  htd_rules=$UCONFDIR/rules/$hostname.tab
  ns_tab=$UCONFDIR/namespace/$hostname.tab

  which tmux 1>/dev/null || {
    export PATH=/usr/local/bin:$PATH
  }

  which rst2xml 1>/dev/null && rst2xml=$(which rst2xml) || {
    which rst2xml.py 1>/dev/null && rst2xml=$(which rst2xml.py) ||
      warn "No rst2xml"
  }

  test -n "$htd_session_id" || htd_session_id=$(htd__uuid)

  # Process subcmd 'run' flags, single letter code triggers load/unload actions.
  # Sequence matters. Actions are predefined, or supplied using another subcmd
  # attribute. Action callbacks can be a first class function, or a literal
  # function name.
  local flags="$(try_value "${subcmd}" run htd | sed 's/./&\ /g')"
  test -z "$flags" || stderr debug "Flags for '$subcmd': $flags"
  for x in $flags
  do case "$x" in

    A ) # 'argsv' callback gets subcmd arguments, defaults to opt_arg.
    # Underlying code usually expects env arguments and options set. Maybe others.
    # See 'i'. And htd_inputs/_outputs env.
        local htd_subcmd_argsv=$(echo_local $subcmd argsv)
        func_exists $htd_subcmd_argsv || {
          htd_subcmd_argsv="$(eval echo "\$$htd_subcmd_argsv")"
          # std. behaviour is a simmple for over the arguments that sorts
          # '-' (hyphen) prefixed words into $options, others into $arguments.
          test -n "$htd_subcmd_argsv" || htd_subcmd_argsv=opt_args
        }
        $htd_subcmd_argsv "$@"
      ;;

    a ) # trigger 'argsv' attr. as argument-process-code
        local htd_args_handler="$(eval echo "\$$(echo_local $subcmd argsv)")"
        case "$htd_args_handler" in

          arg-groups* ) # Read in '--' separated argument groups, ltr/rtl
            test "$htd_args_handler" = arg-groups-r && dir=rtl || dir=ltr

            local htd_arg_groups="$(eval echo "\$$(echo_local $subcmd arg-groups)")"

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
                local htd_defargs="$(eval echo "\$$(echo_local $subcmd defargs-$group)")"
                test -z "$htd_defargs" \
                  || { echo $htd_defargs | words_to_lines >>$arguments.$group; }
              }
            done
            test -z "$DEBUG" || wc -l $arguments*

          ;; # /arg-groups*
        esac
      ;; # /argv-handler

    e ) # env: default/clear for env
        local htd_subcmd_env=$(try_value $subcmd env htd)
        test -n "$htd_subcmd_env" ||
          error "run 'e': $subcmd env attr is empty" 1
        eval $htd_subcmd_env
        info "1. Env: $(var2tags $(echo $htd_subcmd_env | sed 's/=[^\ ]*//g' ))"
      ;;

    f ) # failed: set/cleanup failed varname
        export failed=$(setup_tmpf .failed)
      ;;
    H )
        req_htdir || stderr error "HTDIR required ($HTDIR)" 1
      ;;

    I ) # setup (numbered) IO descriptors for htd-input/outputs (requires i before)
        req_vars $htd_inputs $htd_outputs
        local fd_num=2 io_dev_path=$(io_dev_path)
        for fd_name in $htd_outputs $htd_inputs
        do
          fd_num=$(( $fd_num + 1 ))
          # TODO: only one descriptor set per proc, incl. subshell. So useless?
          test -e "$io_dev_path/$fd_num" || {
            debug "exec $(eval echo $fd_num\\\>$(eval echo \$$fd_name))"
            eval exec $fd_num\>$(eval echo \$$fd_name)
          }
        done
      ;;

    i ) # io-setup: set all requested io varnames with temp.paths
        stderr debug "Exporting inputs '$(try_value inputs)' and outputs '$(try_value outputs)'"
        setup_io_paths -$subcmd-${htd_session_id}
        export $htd__inputs $htd__outputs
      ;;

    m )
        # TODO: Metadata blob for host
        metadoc=$(statusdir.sh assert)
        exec 4>$metadoc.fkv
      ;;

    O ) # 'optsv' callback is expected to process $options from input(s)
        local htd_subcmd_optsv=$(echo_local $subcmd optsv)
        func_exists $htd_subcmd_optsv || {
          htd_subcmd_optsv="$(eval echo "\"\$$htd_subcmd_optsv\"")"
          test -n "$htd_subcmd_optsv" || htd_subcmd_optsv=htd_optsv
        }
        test -e "$options" && {
          $htd_subcmd_optsv "$(cat $options)"
        } || noop
      ;;

    P )
        local prereq_func="$(eval echo "\"\$$(echo_local $subcmd pre)\"")"
        test -z "$prereq_func" || $prereq_func $subcmd
      ;;

    p )
        pwd="$(pwd -P)"
        package_file $pwd && update_package $pwd
        package_lib_load "$pwd"
        test -e "$PACKMETA_SH" && . $PACKMETA_SH
        test -n "$package_id" && {
          note "Found package '$package_id'"
        } || {
          package_id="$(basename "$(realpath .)")"
          note "Using package ID '$package_id'"
        }
      ;;

    S )
        # Get a path to a storage blob, associated with the current base+subcmd
        S=$(try_value "${subcmd}" S htd)
        test -n "$S" \
          && status=$(setup_stat .json "" ${subcmd}-$(eval echo $S)) \
          || status=$(setup_stat .json)
        exec 5>$status.pkv
      ;;

    x ) # ignores, exludes, filters
        htd_load_ignores
      ;;

    esac
  done

  # load extensions via load/unload function
  for ext in $(try_value "${subcmd}" load htd)
  do
    htd_load_$ext || warn "Exception during loading $subcmd $ext"
  done
}

htd_unload()
{
  local unload_ret=0
  for x in $(try_value "${subcmd}" run htd | sed 's/./&\ /g')
  do case "$x" in

    I )
        local fd_num=2
        for fd_name in $htd_outputs $htd_inputs
        do
          fd_num=$(( $fd_num + 1 ))
          #eval echo $fd_num\\\<\\\&-
          eval exec $fd_num\<\&-
        done
        eval unset $htd_inputs $htd_outputs
        unset htd_inputs htd_outputs
      ;;

    i ) # remove named IO buffer files; set status vars
        clean_io_lists $htd__inputs $htd__outputs
        htd_report $htd__outputs || unload_ret=$?
      ;;

    P )
        local postreq_func="$(eval echo "\"\$$(echo_local $subcmd post)\"")"
        test -z "$postreq_func" || $postreq_func $subcmd
      ;;

    r )
        # Report on scriptnames and associated script-lines provided in $HTD_TOOLSFILE
        cat $report | jsotk.py -O yaml --pretty dump -
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

  esac; done

  clean_failed || unload_ret=1

  for var in $(try_value "${subcmd}" vars htd)
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
  # Initialize one IGNORE_GLOBFILE file.
  ignores_lib_load
  test -n "$IGNORE_GLOBFILE" -a -e "$IGNORE_GLOBFILE" ||
      error "expected $base ignore dotfile" 1
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
  req_dir_env HTDIR
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
  echo '  git-grep                         See htd help git-grep'
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

htd__libs_raw()
{
  locate_name $base
  note "Raw lib routine listing for '$fn' script"
  dry_run= box_list_libs "$fn"
}

htd__libs()
{
  locate_name $base
  note "Script: '$fn'"
  box_lib "$fn"
  note "Libs: '$box_lib'"
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


htd_man_1__output_formats='List output formats for sub-command. The format is a
tag that refers to the formatting on stdout of data or responses to invocations
of the subcommand::

    out_fmt=<fmt> htd <subcmd> <args>...

For each output format a quality factor may be specified, to indicate levels of
*increased* or *degraded* representation. The application of this value is
similar to the source-quality attribute in HTTP TCN (RFC 2295), except that this
raw value is not normalized to =<1.0.

In general, the value is used to weigh rendering quality and should not take
into account delay or load. Here, default values of 0.9 are used, because the
shell scripts at themselves make too little guarantee of encoding and other
precision. Values above 1.0 are permitted to indicate preferred, enhanced or
richer representations.

No current But no effort is made to 

htd_output_format_q 

the `ofq` attribute 
'
htd_spc__output_formats='output-formats|OF [SUBCMD]'
htd_als___OF=output-formats
htd_of__output_formats='list csv tab json'
htd_f__output_formats='fmt q'
htd_ofq__output_formats='htd_output_formats_q'
htd__output_formats()
{
  test -n "$1" || set -- table-reformat
  # First resolve real command name if given an alias
  als="$(try_value "$1" als htd )"
  test -z "$als" || set -- "$als"
  {
    # Retrieve and test for output-formats and quality factor
    try_func $(echo_local "$1" "" htd) && 
      output_formats="$(try_value "$1" of htd )" &&
        test -n "$output_formats"
  } && {
    echo $output_formats | tr ' ' '\n'
  } || {
    error "No sub-command or output formats for '$1'" 1
  }
}


htd_man_1__version="Version info"
htd__version()
{
  echo "$scriptname/$version"
  #echo "$package_id/$version"
}
#htd_als___V=version
htd_als____version=version
htd_run__version=p


htd__home()
{
  req_dir_env HTDIR
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
  log "Ignored paths:         '$IGNORE_GLOBFILE' [IGNORE_GLOBFILE]"
}


htd__expand()
{
  test -n "$1" || return 1
  for x in $@
  do
    test -e "$x" && echo "$x"
  done
}


htd_man_1__edit_main="Edit the main script file(s), and add arguments"
htd_spc__edit_main="-E|edit-main [ --search REGEX ] [ID-or-PATHS]"
htd__edit_main()
{
  local evoke= files="$(cat $arguments)" fn=
  locate_name || return 1
  vim_swap "$(realpath "$fn")" || error "swap file exists for '$fn'" 2
  files="$files $fn $(columnize=false htd__ls_main_files | lines_to_words )"
  # XXX:
  #libs_n_docs="\
  #  $(dirname $fn)/$(basename "$fn").lib.sh \
  #  $(dirname $fn)/$(basename "$fn").rst \
  #  $(dirname $fn)/*.lib.sh"
  test "$EDITOR" = "vim" || error "unsupported '$EDITOR'" 1
  evoke="vim "
  # Search in first pane
  test -z "$search" ||
    evoke="$evoke -c \"/$search\""
  # Two vertical panes (O2), with additional h-split in the right
  #evoke="$evoke -O2
  evoke="$evoke \
    -c :vsplit \
    -c \":wincmd l\" \
    -c \"normal gg $\" \
    -c :split \
    -c \"wincmd j\" \
    -c \"normal G $\" \
    -c \"wincmd h\""
  printf "$(tput bold)$(tput setaf 0)$evoke $files$(tput sgr0)\n"
  bash -c "$evoke $files"
}
htd_run__edit_main=iAO
htd_als___XE=edit-main


htd__ls_main_files()
{
  default_env columnize 1
  {
    for scr in $scriptpath/*.sh
    do
      fnmatch "*.inc.sh" "$scr" && continue
      fnmatch "*.lib.sh" "$scr" && continue
      test -x "$scr" || continue
      basename $scr
    done
  } | {
    trueish "$columnize" && column_layout || cat
  }
}


htd_man_1__edit_local="Edit an existing local file, or abort. "
htd_spc__edit_local="-e|edit <id>"
htd__edit()
{
  test -n "$1" || error "search term expected" 1
  case "$1" in
    # NEW
    sandbox-jenkins-mpe | sandbox-mpe-new )
        cd $UCONFDIR/vagrant/sandbox-trusty64-jenkins-mpe
        vim Vagrantfile
      ;;
    treebox-new )
        cd $UCONFDIR/vagrant/
        vim Vagrantfile
      ;;
  esac
  doc_path_args
  find_paths="$(doc_find_name "$1")"
  grep_paths="$(doc_grep_content "$1")"

  test -n "$find_paths" -o -n "$grep_paths" \
    || error "Nothing found to edit" 1
  $EDITOR $find_paths $grep_paths
}
htd_als__edit=edit-local
htd_als___e=edit-local


htd_man_1__find="Find file by name, or abort.

Searches every integrated source for a filename: volumes, repositories,
archives. See 'search' for looking inside files. "
htd_spc__find="-f|find <id>"
htd__find()
{
  test -n "$1" || error "name pattern expected" 1
  test -z "$2" || error "surplus argumets '$2'" 1

  note "Compiling ignores..."
  local find_ignores="$(find_ignores $IGNORE_GLOBFILE)"

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
  case "$1" in
    list )
        htd__ls_volumes
      ;;
  esac
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
  test -n "$failed" || error "status: failed exists" 1

  local pwd=$(pwd -P) ppwd=$(pwd) spwd=. scm= scmdir=
  vc_getscm && {
    cd "$(dirname "$scmdir")"
    vc_clean "$(vc_dir)"
  }
}
htd__status_update() { # TODO: cleanup
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
      $LOG "header3" "$path" ""
      continue
    }
    $LOG "header3" "$path" "" "$( cd $path && vc.sh flags )"
    #$scriptpath/std.lib.sh ok "$path"
  done

  # FIXME: maybe something in status backend on open resource etc.
  #htd__recent_paths
  #htd__active

  stderr note "text-paths for main-docs: "
  # Check main document elements
  {
    test ! -d "$JRNL_DIR" ||
      EXT=$DOC_EXT htd__archive_path $JRNL_DIR
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
    && { rm $status || noop; }

  # FIXME: statusdir tools script listing
  rm $status
  # Regenerate status data for this script if not available
  test -s $status || {
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

htd_man_1__tools='Tools manages simple installation scripts from YAML and is
  usable to keep scripts in a semi-portable way, that do not fit anywhere else.

  It works from a metadata document that is a single bag of IDs mapped to
  objects, whose schema is described in schema/tools.yml. It can be used to keep
  multiple records for the same binary, providing alternate installations for
  the same tools.

'
htd_spc__tools="tools (<action> [<args>...])"
htd__tools()
{
  tools_json || return 1
  test -n "$1" || set -- status

  case "$1" in
    install ) shift ;                         htd__install "$@" ;;
    uninstall ) shift ;                       htd__uninstall "$@" ;;
    list-local | installed | status ) shift ; htd__installed "$@" ;;
    outline-doc ) shift ;                     htd__tools_outline "$@" ;;
    validate-doc | validate ) shift ;         htd__tools_validate "$@" ;;
    * ) error "No such tools subcommand '$1'" 1 ;;
  esac
}
htd_grp__tools=htd-tools

htd_of__installed='yml'
htd__installed()
{
  tools_json || return 1 ; upper=0 default_env out-fmt tty
  test -n "$1" || set -- $(tools_list) ; test -n "$*" || return 2 ;
  test "$out_fmt" = "yml" && echo "tools:" ; while test -n "$1"
  do
    installed $B/tools.json "$1" && {
      note "Tool '$1' is present"
      test "$out_fmt" = "yml" && printf "  $1:\n    installed: true\n" || noop
    } || {
      test "$out_fmt" = "yml" && printf "  $1:\n    installed: false\n" || noop
    }
    shift
  done
}
htd_grp__installed=htd-tools

htd_man_1__install=""
htd_spc__install="install [TOOL...]"
htd__install()
{
  tools_json || return 1 ; local verbosity=6 ; while test -n "$1"
  do
    install_bin $B/tools.json $1 \
      && info "Tool $1 is installed" \
      || info "Tool $1 install error: $?"
    shift
  done
}
htd_grp__install=htd-tools

htd__uninstall()
{
  tools_json || return 1 ; local verbosity=6 ; while test -n "$1"
  do
    uninstall_bin $B/tools.json "$1" \
      && info "Tool $1 is not installed" \
      || { r=$?;
        test $r -eq 1 \
          && info "Tool $1 uninstalled" \
          || info "Tool uninstall $1 error: $r" $r
      }
    shift
  done
}
htd_grp__uninstall=htd-tools

htd__tools_validate()
{
  tools_json || return 1
  tools_json_schema || return 1
  # Note: it seems the patternProperties in schema may or may not be fouling up
  # the results. Going to venture to outline based format first before returning
  # to which JSON schema spec/validator supports what.
  jsonschema -i $B/tools.json $B/tools-schema.json &&
      stderr ok "jsonschema" || stderr warn "jsonschema"
  jsonspec validate --document-file $B/tools.json \
    --schema-file $B/tools-schema.json &&
      stderr ok "jsonspec" || stderr warn "jsonspec"
}
htd_grp__tools_validate=htd-tools

htd_man_1__tools_outline='Transform tools.json into an outline compatible
format.
'
htd__tools_outline()
{
  rm $B/tools.json
  tools_json || return 1
  out_fmt=yml htd__installed | jsotk update --pretty -Iyaml $B/tools.json -
  { cat <<EOM
{ "id": "$(htd__prefix_name "$(pwd -P)")/tools.yml",
  "hostname": "$hostname", "updated": ""
}
EOM
} | jsotk update -Ijson --pretty $B/tools.json -
  { cat <<EOM
{
  "pretty": true, "doc": $(cat $B/tools.json)
}
EOM
} > $B/tools-outline-pug-options.json
  pug -E xml --out $B/ \
    -O $B/tools-outline-pug-options.json var/tpl/pug/tools-outline.pug
}
htd_grp__tools_outline=htd-tools


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
  fixed_table $ns_tab SID GROUPID| while read vars
  do
    eval local "$vars"
    echo $SID
  done
}

# TODO: List namespaces matching query
htd_spc__ns_names='ns-names [<path>|<localname> [<ns>]]'
htd__ns_names()
{
  test -z "$3" || error "Surplus arguments: $3" 1
  fixed_table $ns_tab SID GROUPID | while read vars
  do
    eval local "$vars"
    note "FIXME: $SID eval local var from pathnames.tab"
    continue
    cd $CMD_PATH
    note "In '$ID' ($CMD_PATH)"
    eval $CMD "$1"
    cd $CWD
  done
}


# Run a sys-* target in the main htdocs dir.
htd__make_sys()
{
  req_dir_env HTDIR
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
  test -n "$EXT" || EXT=.rst
  local pwd=$(pwd) arg=$1
  test -n "$1" || set -- journal/
  fnmatch "*/" "$1" && {

    case "$1" in *journal* )
      set -- $JRNL_DIR
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
        htd_rst_doc_create_update "$today" "$title" created default-rst
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
htd_als__vt=edit-today


htd__edit_week()
{
  {
    note "Editing $1"
    htd__today "$1"
    today=$(realpath $1/today.rst)
    test -s "$today" || {
      title="$(date_fmt "" '%A %G.%V')"
      htd_rst_doc_create_update "$today" "$title" created default-rst
    }
    #FILES=$(bash -c "echo $1/{today,tomorrow,yesterday}$EXT")
    htd_edit_and_update $1 #$(realpath $FILES)
  } || {
    error "err $1/ $?" 1
  }
}
htd_als__vw=edit-week
htd_als__ew=edit-week


htd_spec__archive_path='archive-path DIR PATHS..'
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
htd__today() # Jrnl-Dir MSep
{
  test -n "$1" || set -- "$(pwd)/$JRNL_DIR" "$2" "$3" "$4"
  test -n "$2" || set -- "$1" "/" "$3" "$4"
  test -n "$3" || set -- "$1" "$2" "-" "$4"
  test -n "$4" || set -- "$1" "$2" "$3" "-"
  test -d "$1" || error "Dir $1 must exist" 1
  set -- "$(strip_trail "$1")" "$2" "$3" "$4"

  # Append pattern to given dir path arguments
  local YSEP=/ Y=%Y MSEP=- M=%m DSEP=- D=%d
  local r=$1$YSEP
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
}


htd_als__week=this-week
htd__this_week()
{
  test -n "$1" || set -- "$(pwd)/log" "$2"
  test -n "$2" || set -- "$1" "/"
  test -d "$1" || error "Dir $1 must exist" 1
  set -- "$(strip_trail "$1")" "$2"

  # Append pattern to given dir path arguments
  default_env W %Yw%V
  default_env WSEP /
  local r=$1$WSEP
  default_env EXT .rst
  set -- "$1$WSEP$W$EXT"

  datelink "" "$1" ${r}week$EXT
  datelink "-7d" "$1" "${r}last-week$EXT"
  datelink "+7d" "$1" "${r}next-week$EXT"
}

htd__edit_week()
{
  test -n "$1" || set -- log
  note "Editing $1"
  #git add $1/[0-9]*-[0-9][0-9]-[0-9][0-9].rst
  htd__this_week "$1"
  week=$(realpath $1/week.rst)
  test -s "$week" || {
    title="$(date_fmt "" '%G.%V')"
    htd_rst_doc_create_update "$week" "$title" week created default-rst
  }
  # FIXME: bashism since {} is'nt Bourne Sh, but csh and derivatives..
  FILES=$(bash -c "echo $1/{week,last-week,next-week}$EXT")
  htd_edit_and_update $(realpath $FILES)
}


htd_man_1__jrnl='
    TODO: status check update
    list [Prefix=2...]
        List entries with prefix, use current year if empty. Set to * for
        listing everything.
    entries
        XXX: resolve metadata
'
htd__jrnl()
{
  test -n "$1" || set -- status
  case "$1" in

    status )
      ;;

    check )
      ;;

    update ) shift
        test -n "$1" || set -- $JRNL_DIR/entries.list
        htd__jrnl list '*' |
            htd__jrnl entries |
            htd__jrnl ids > $1.tmp

        c=$(count_lines "$1")
        enum_nix_style_file $1.tmp | while read n id line
        do
          printf -- "$id: $line idx:$n "
          test $n -gt 1 && {
            printf -- " prev:$(source_line $1.tmp $(( $n - l )) ) "
          }                                                 
          test $n -lt $c && {                                 
            printf -- " next:$(source_line $1.tmp $(( $n + 1 )) ) "
          }
          echo
        done > $1

        rm $1.tmp
      ;;

    entries ) shift
        JRNL_ENTRY_G="[0-9][0-9][0-9][0-9]?[0-9][0-9]?[0-9][0-9].*"
        while read id l
        do
          fnmatch $JRNL_ENTRY_G "$id" || continue
          echo "$id $l"
        done
      ;;

    ids ) shift
        while read p
        do echo "$( basename "$p" .rst )"
        done
      ;;

    list ) shift
        test -n "$1" || set -- $(date +'%Y')
        w=$(( ${#JRNL_DIR} + 2 ))
        for p in $JRNL_DIR/$1*.rst
        do
          test -f "$p" && {
            echo "$p" | cut -c$w-
            continue
          }
          test -h "$p" && {
            echo "$(echo "$p" | cut -c$w-) -> $(readlink "$p")"
          } || {
            warn "$p"
          }
        done
      ;;

    to-couch ) shift
        test -n "$1" || set -- $JRNL_DIR/entries.list
        htd__txt to-json "$1"
      ;;

    * ) error "'$1'? 'htd jrnl $*'" 1 ;;
  esac
}

htd_of__jrnl_json='json-stream'
htd__jrnl_json()
{
  test -n "$1" || set -- $JRNL_DIR/entries.list
  htd__txt to-json "$1"
}


# TODO: use with edit-local
htd__edit_note()
{
  test -n "$1" || error "ID expected" 1
  test -n "$2" || error "tags expected" 1
  test -z "$3" || error "surplus arguments" 1
  req_dir_env HTDIR

  id="$(printf "$1" | tr -cs 'A-Za-z0-9' '-')"
  #id="$(echo "$1" | sed 's/[^A-Za-z0-9]*/-/g')"

  case " $2 " in *" nl "* | *" en "* ) ;;
    * ) set -- "$1" "$2 en" ;; esac
  fnmatch "* rst *" " $2 " || set -- "$1" "$2 rst"
  ext="$(printf "$(echo $2)" | tr -cs 'A-Za-z0-9_-' '.')"

  note=$HTDIR/note/$id.$ext
  htd_rst_doc_create_update $note "$1" created default-rst
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
htd__main_doc_edit()
{
  # Find first standard main document
  test -n "$1" || set -- "$(htd__main_doc_paths "$1"|{ read tag path;echo $path; })"
  # Or set default
  test -n "$1" || set -- main$DOC_EXT

  # Open edit session, discard unchanged generated file
  local cksum=
  title="$(str_title "$(basename "$(pwd -P)")")"
  htd_rst_doc_create_update $1 "$title" created default-rst
  htd_edit_and_update $1
}
htd_als__md=main-doc-edit
htd_als___E=main-doc-edit



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
  test -n "$1" || error host 1
  test -n "$2" || {
    test -e $UCONFDIR/disk/$hostname-$1.user && {
      set -- "$1" "$(head -n 1 $UCONFDIR/disk/$hostname-$1.user )"
    }
  }
  # Unmount remote disks from local mounts
  test -e $UCONFDIR/disk/$hostname-$1.list && {
    note "Unmounting from local.."
    mounts="$(read_nix_style_file $UCONFDIR/disk/$hostname-$1.list | lines_to_words)"
    sudo umount "$mounts"
  }
  ssh_req $1 $2 &&
  run_cmd "$1" 'sudo shutdown -h +1' &&
  note "Remote shutdown triggered: $1"
}


htd__ssh_vagrant()
{
  test -d $UCONFDIR/vagrant/$1 || error "No vagrant '$1'" 1
  cd $UCONFDIR/vagrant/$1
  vagrant up --provision || {
    warn "Provision error $?. See htd edit to review Vagrantfile. "
    sys_confirm "Continue with SSH connection?" ||
        note abort 1
  }
  vagrant ssh
}


htd_run__ssh=f
htd__ssh()
{
  case "$1" in
    # NEW
    sandbox-jenkins-mpe | sandbox-new )
        id=sandbox-trusty64-jenkins-mpe
        shift
        set -- $id "$@"
        htd__ssh_vagrant "$1"
      ;;

    # TODO: move to vagrants
    sandbox | sandbox-mpe | vdckr | vdckr-mpe )
        cd $UCONFDIR/dckr/ubuntu-trusty64-docker-mpe/
        vagrant up
        vagrant ssh
      ;;

    # OLD vagrants
    treebox | treebox-precise | treebox-mpe )
        cd $UCONFDIR/vagrant/treebox-hashicorp-precise-mpe
        vagrant up
        vagrant ssh
      ;;
    trusty )
        cd $UCONFDIR/vagrant/ubuntu-trusty64
        vagrant up
        vagrant ssh
      ;;

    # TODO: harbour aliases in private space shomehow
    dandy-home )     htd ssh dandy "export CS=$CS; cd ~/ && bash -i " ;;
    dandy-conf )     htd ssh dandy "export CS=$CS; cd ~/.conf && bash -i " ;;
    dandy-bin )      htd ssh dandy "export CS=$CS; cd ~/bin && bash -i " ;;
    dandy-htd )      htd ssh dandy "export CS=$CS; cd ~/htdocs && bash -i " ;;

    # @Home
    * )
        # Try for minimally a minute to wake/contact remote
        test -n "$retries" || retries=6
        ret=0
        htd__detect_ping $1 || {
          while true
          do
            test $retries -gt 0 ||
              stderr warn "Unable to contact '$1' in allotted retries" 1
            note "Trying to wake up $1.."
            htd wake $1 || error "wol error $?" 1
            retries=$(( $retries - 1 ))
            sleep 16
            stderr info "Testing ping to '$1'..."
            htd__detect_ping $1 && break
          done
        }
        test -n "$2" &&
          note "Host '$1' is online, trying command '$2'.." ||
          note "Host '$1' is online, trying ssh connect.."

        ssh -t $1 "export CS=$CS; $2" || ret=$?
        test -n "$2" && {
          test -z "$ret" -o "$ret" = "0" &&
            note "Command $1: '$2' completed OK" ||
            error "Command $1: '$2' failed exiting $ret" 2
        } || {
          test -z "$ret" -o "$ret" = "0" &&
            note "SSH connection to '$1' completed and closed" ||
            error "SSH connection to '$1' exited $ret" 1
        }
      ;;

    * )
        error "No remote $1"
      ;;
  esac
}


htd_man_1__up='Test all given hosts are online and answering'
htd__up()
{
  test -n "$1" || set -- ping
  case "$1" in

    ping ) shift ; htd__detect_ping "$@" || return $? ;;

    aping|ansping ) shift ;
        test -z "$*" || stderr error "No arguments expected" 1
        ansible all -m ping || return $?
      ;;

    * ) error "'$1'? (htd up $*)" 1 ;;
  esac
}
htd_run__up=f
htd_als__detect=up

htd_man_1__detect_ping='Test all given hosts are online, answering to PING'
htd__detect_ping() # Hosts...
{
  test -n "$failed" || error "detect-ping expects failed env" 1
  while test $# -gt 0
  do
    ping -qt 1 -c 1 $1 >/dev/null &&
      stderr ok "$1" || echo "htd:$subcmd:detect-ping:$1" >$failed
    shift
  done
  test ! -s "$failed"
}
htd_run__detect_ping=f


# Simply list ARP-table, may want something better like arp-scan or an nmap
# script
htd__mac()
{
  arp -a
}


htd_man_1__random_str="Print a web/url-save case-sensitive Id of length. It is
 base64 encoded, so multiples of 3 make sense as length, or they will be padded
 to length. "
htd_spc__random_str='(rndstr|random-str) [12]'
htd_als__rndstr=random-str
htd__random_str()
{
  test -n "$1" || set -- 12
  python -c "import os, base64;print base64.urlsafe_b64encode(os.urandom($1))"
}


htd__new_object()
{
  cat
  htd__random_str
}


# todo.txt/list.txt util

htd__txt()
{
  test -n "$1" || set --
  case "$1" in

    to-json ) shift
        txt.py meta-to-json "$1"
      ;;

    number | enumerate ) shift
        offset=0
        for list in "$@"
        do
          enum_nix_style_file "$list" | while read num line
          do
            echo "$(( $offset + $num )) $line"
          done
          offset=$(( $offset + $(line_count "$list" ) ))
        done
      ;;

    * ) error "'$1'? 'htd txt $*'" 1 ;;
  esac
}


# Current tasks

htd_man_1__tasks='More context for todo.txt files - see also "htd help todo".

  Print package pd-meta tags setting using:

    htd package pd-meta tags
    htd package pd-meta tags-document
    htd package pd-meta tags-done
    .. etc,

  See also package.rst docs.
  The first two arguments TODO/DONE.TXT default to tags-document and tags-done.
  Other commands in this group:

    htd tasks-scan
    htd tasks-grep
    htd tasks-local
    htd tasks-edit
    htd tasks-hub
    htd tasks-buffers
    htd tasks-tags

    htd tasks scan|grep|local|edit|buffers|hub
    htd tasks tags[-{project,context}]

  See tasks-hub for more local functions.
'

htd_man_1__tasks_scan="Update todo/tasks/plan document from local tasks"
htd_spc__tasks_scan='tasks-scan [ --interactive ] [ --Check-All-Tags ] [ --Check-All-Files ]'
htd__tasks_scan()
{
  htd_tasks_load
  note "Scanning tasks.. ($(var2tags  todo_slug todo_document todo_done ))"
  local grep_Hn=$(setup_tmpf .grep-Hn)
  mkdir -vp $(dirname "$grep_Hn")
  { htd__tasks_local > $grep_Hn
  } || error "Could not update $grep_Hn" 1
  test -z "$todo_slug" && {
    warn "Slug required to update store for $grep_Hn ($todo_document)"
  } ||  {
    note "Updating tasks document.. ($todo_document $(var2tags verbose choice_interactive))"
    tasks_flags="$(
      falseish "$verbose" || printf -- " -v ";
      falseish "$choice_interactive" || printf -- " -i ";
    )"
    # FIXME: select tasks backend
    be_opt="-t $todo_document --link-all"
    #be_opt="--redis"
    tasks.py $tasks_flags -s $todo_slug read-issues \
      --must-exist -g $grep_Hn $be_opt \
        || error "Could not update $todo_document " 1
    note "OK. $(read_nix_style_file $todo_document | count_lines) task lines"
  }
}
htd_run__tasks_scan=iAOp


htd_man_1__tasks_grep="Use Htd's built-in todo grep list command to get local
 tasks. Output is like 'grep -nH': '<filename>:<linenumber>: <line-match>'"
htd_spc__tasks_grep='tasks-grep [ --tasks-grep-expr | --Check-All-Tags] [ --Check-All-Files]'
htd__tasks_grep()
{
  local out=$(setup_tmpf .out)
  # NOTE: not using tags from metadata yet, need to build expression for tags
  trueish "$Check_All_Tags" && {
    test -n "$tasks_grep_expr" ||
      tasks_grep_expr='\<\(TODO\|FIXME\|XXX\)\>' # tasks:no-check
  } || {
    test -n "$tasks_grep_expr" || tasks_grep_expr='\<XXX\>' # tasks:no-check
  }
  test -e .git && src_grep="git grep -nI" || src_grep="grep -nsrI \
      --exclude '*.html' "
  # Use local settings to filter grep output, or set default
  local $(package_sh id pd_meta_tasks_grep_filter)
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
htd_run__tasks_grep=iAO


htd_man_1__tasks_local="Use the preferred local way of creating the local todo grep list"
htd_spc__tasks_local='tasks-local [ --Check-All-Tags ] [ --Check-All-Files ]'
htd__tasks_local()
{
  local $(map=package_pd_meta_:htd_ package_sh tasks_grep)
  test -n "$htd_tasks_grep" && {
    Check_All_Tags=1 Check_All_Files=1  \
    $htd_tasks_grep
    return 0
  } || {
    htd__tasks_grep
  }
}
htd_run__tasks_local=iAO


htd_man_1__tasks_edit='Invoke htd todotxt-edit for local package'
htd_spc__tasks_edit="tasks-edit TODO.TXT DONE.TXT [ @PREFIX... ] [ +PROJECT... ] [ ADDITIONAL-PATHS ]"
# This reproduces most of the essential todotxt-edit code, b/c before migrating
# we need exclusive access to update the files anyway.
htd_env__tasks_edit='
  id=$htd_session_id migrate=1 remigrate=1
  todo_slug= todo_document= todo_done=
  tags= projects= contexts= buffers= add_files= locks=
  colw=32
'
htd__tasks_edit()
{
  info "2.1. Env: $(var2tags id todo_slug todo_document todo_done tags buffers add_files locks colw)"
  htd__tasks_session_start
  set -- "$todo_document" "$todo_done"
  info "2.2. Env: $(var2tags id todo_slug todo_document todo_done tags buffers add_files locks colw)"
  # TODO: If locked import principle tasks to main
  trueish "$migrate" &&
    htd_migrate_tasks "$1" "$2"
  info "2.3. Env: $(var2tags id todo_slug todo_document todo_done tags buffers add_files locks colw)"
  # Edit todo and done file
  $TODOTXT_EDITOR "$1" "$2"
  # Relock in case new tags added
  # TODO: diff new locks
  #newlocks="$(lock_files $id "$1" | lines_to_words )"
  #note "Acquired additional locks ($(basenames ".list" $newlocks | lines_to_words))"
  # TODO: Consolidate all tasks to proper project/context files
  info "2.6. Env: $(var2tags id todo_slug todo_document todo_done tags buffers add_files locks colw)"
  trueish "$remigrate" &&
    htd_remigrate_tasks "$1" "$2"
  # XXX: where does @Dev +script-mpe go, split up? refer principle tickets?
  htd__tasks_session_end "$1" "$2"
}
htd_run__tasks_edit=eA
htd_argsv__tasks_edit=htd_argsv__tasks_session_start
htd_als__edit_tasks=tasks-edit


htd_man_1__tasks_hub='Given a tasks-hub directory, either get tasks, tags or
  additional settings ie. backends, indices, cardinality.

    htd tasks-hub be
    htd tasks-hub tags
    htd tasks-hub tagged

'
htd_man_1__tasks_hub_init='Figure out identity for buffer lists'
htd_man_1__tasks_hub_be='List the backend scripts'
htd_man_1__tasks_hub_tags='List tags for which buffers exist'
htd_man_1__tasks_hub_tagged='Lists unique tags from items in lists, or any
  matching line in a hub leaf. '
htd_env__tasks_hub='projects=1 contexts=1'
htd_spc__tasks_hub='tasks-hub [ (be|tags|tagged) [ ARGS... ] ]'
htd_spc__tasks_hub_taggged='tasks-hub tagged [ --all | --lists | --endpoints ] [ --no-projects | --no-contexts ] '
htd__tasks_hub()
{
  test -n "$1" || set -- be
  htd_tasks_load init $subcmd
  case "$1" in
    init )
  contexts=0 htd__tasks_hub tags | tr -d '+' | while read proj
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
        htd__tasks_tags $todo_document
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
    tags )
        trueish "$contexts" && {
        test "$(echo $tasks_hub/do-at-*.*)" = "$tasks_hub/do-at-*.*" &&
          warn "No contexts" ||
        for task_list in $tasks_hub/do-at-*.*
        do
          echo "@$(basenames "$TASK_EXTS .sh" "$task_list" | cut -c7-)"
        done; }
        trueish "$projects" && {
        test "$(echo $tasks_hub/do-in-*.list)" = "$tasks_hub/do-in-*.list" &&
          warn "No projects" ||
        for task_list in $tasks_hub/do-in-*.list
        do
          echo "+$(basenames "$TASK_EXTS .sh" "$task_list" | cut -c7-)"
          #echo "+$(basename "$task_list" .list | cut -c7-)"
        done; }
      ;;
    tagged )
      # TODO: switch file selection liek in tags above
        test "$(echo $tasks_hub/*.*)" = "$tasks_hub/*.*" &&
          warn "No files to look for tags" ||
            htd__todotxt_tags $tasks_hub/*.*
      ;;
    * ) error "tasks-hub? '$*'" ;;
  esac
}
htd_run__tasks_hub=eiAOp


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

htd__tasks_process()
{
  projects=0 htd__tasks_hub tags | tr -d '@' | while read ctx
  do
    echo arg ctx: $ctx
  done
}
htd_run__tasks_process=A
htd_argsv__tasks_process=htd_argsv__tasks_session_start
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
  local dir=to/
  for tag in $@
  do
    case "$tag" in
      @be.* ) be=$(echo $tag | cut -c5- )
          echo to/be-$be.sh
        ;;
      +* ) prj=$(echo $tag | cut -c2- )
          echo to/do-in-$prj.lst
          echo cabinet/done-in-$prj.lst
          echo to/do-in-$prj.list
          echo cabinet/done-in-$prj.list
          echo to/do-in-$prj.sh
        ;;
      @* ) ctx=$(echo $tag | cut -c2- )
          echo to/do-at-$ctx.lst
          echo cabinet/done-at-$ctx.lst
          echo to/do-at-$ctx.list
          echo cabinet/done-at-$ctx.list
          echo to/do-at-$ctx.sh
          echo store/at-$ctx.sh
          echo store/at-$ctx.yml
          echo store/at-$ctx.yaml
        ;;
      * ) error "tasks-buffers '$tag'?" 1 ;;
    esac
  done
}


htd_man_1__tasks_tags="Show tags for files. Files do not need to exist. First
  two files will be created. See 'help tasks'. "
htd__tasks_tags()
{
  test -n "$1" || {
    htd_tasks_load
    test -n "$2" || set -- $todo_done "$@"
    set -- $todo_document "$@"
  }
  assert_files $1 $2
  note "Tags for <$*>"
  htd__todotxt_tags "$@"
}


htd_man_1__tasks_session_start=''
htd_spc__tasks_session_start="tasks-session-start TODO.TXT DONE.TXT [ @PREFIX... ] [ +PROJECT... ] [ ADDITIONAL-PATHS ]"
htd_env__tasks_session_start="$htd_env__tasks_edit"
htd__tasks_session_start()
{
  info "3.1. Env: $(var2tags id todo_slug todo_document todo_done tags buffers add_files locks colw)"
  set -- $todo_document $todo_done
  assert_files $1 $2
  # Accumulate tasks, to find additional files for locking
  tags="$(htd__todotxt_tags "$1" "$2" | lines_to_words ) $tags"
  note "Tags: ($(echo "$tags" | count_words
    )) $(echo "$tags" )"
  info "3.2. Env: $(var2tags id todo_slug todo_document todo_done tags buffers add_files locks colw)"
  # Get paths to all files, add todo/done buffer files per tag
  buffers="$(htd__tasks_buffers $tags )"
  # Lock main files todo/done and additional-paths
  locks="$(lock_files $id "$@" $buffers $add_files | lines_to_words )"
  { exts="$TASK_EXTS" pathnames $locks ; echo; } | column_layout
  # Fail now if main todo/done files are not included in locks
  verify_lock $id $1 $2 || {
    released="$(unlock_files $id $@ $buffers | lines_to_words )"
    error "Unable to lock main files: $1 $2" 1
  }
  note "Acquired locks ($(echo "$locks" | count_words ))"
}
htd_run__tasks_session_start=eiA
htd_argsv__tasks_session_start()
{
  info "1.1. Env: $(var2tags id todo_slug todo_document todo_done tags buffers add_files locks colw)"
  htd_tasks_load
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
  info "1.2. Env: $(var2tags id todo_slug todo_document todo_done tags buffers add_files locks colw)"
}

htd__tasks_session_end()
{
  info "6.1 Env: $(var2tags id todo_slug todo_document todo_done tags buffers add_files locks colw)"
  # clean empty buffers
  for f in $buffers
  do test -s "$f" -o ! -e "$f" || rm "$f"; done
  info "Cleaned empty buffers"
  test ! -e "$todo_document" -o -s "$todo_document" || rm "$todo_document"
  test ! -e "$todo_done" -o -s "$todo_done" || rm "$todo_done"
  # release all locks
  released="$(unlock_files $id "$1" "$2" $buffers | lines_to_words )"
  note "Released locks ($(echo "$released" | count_words ))"
  { exts="$TASK_EXTS" pathnames $released ; echo; } | column_layout
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
  echo
}
htd__tasks()
{
  case "$1" in
    be.src )
        mkvid "$2" ; cmid=$vid
        . ./to/be-src.sh ; shift 2
        htd__tasks__src__${cmid} "$@"
      ;;
    be* )
        be=$(printf -- "$1" | cut -c4- )
        test -n "$be" || error "No default tasks backend" 1
        c= mksid "$1" ; ctxid=$sid
        test -e ./to/$sid.sh || error "No tasks backend '$1' ($be)" 1
        . ./to/$ctxid.sh ;
        mkvid "$be" ; beid=$vid
        mkvid "$2" ; cmid=$vid
        . ./to/$ctxid.sh ; shift 2
        htd__tasks__${beid}__${cmid} "$@"
      ;;
    "" ) shift || noop ; htd__tasks_scan "$@" ;;
    * ) act="$1"; shift 1; htd__tasks_$act "$@" ;;
  esac
}

# Load from pd-meta.tasks.{document,done} [ todo_slug todo-document todo-done ]
htd_tasks_load()
{
  test -n "$1" || set -- init
  while test -n "$1"
  do case "$1" in
    init )
  eval $(map=package_pd_meta_tasks_:todo_ package_sh document done slug )
  test -n "$todo_document" || todo_document=todo.$TASK_EXT
  test -n "$todo_done" ||
    todo_done=$(pathname "$todo_document" $TASK_EXTS)-done.$TASK_EXT
  test -n "$todo_slug" || {
    local $(map=package_ package_sh  id  )
    test -n "$id" && {
      upper=1 mksid "$id"
      todo_slug="$sid"
    }
  }
  test -n "$todo_slug" || error todo-slug 1
  ;;
    tasks-hub | tasks-process )
  test -e "./to" && tasks_hub=./to
  test -n "$tasks_hub" ||
    tasks_hub=$(map=package_pd_meta_ package_sh hub)
  test -n "$tasks_hub" || error tasks-hub 1
  test ! -e "./to" -o "$tasks_hub" = "./to" ||
    error "hub ./to left behind" 1
  ;;
    tags )
  local $(map=package_pd_meta_ package_sh tags)
  test -n "$tasks_tags" ||
    tasks_tags="$(package_sh_list .package.sh pd_meta_tasks_tags \
      | lines_to_words )"
  ;;
    coops )
  local $(map=package_pd_meta_ package_sh coops)
  test -n "$tasks_coops" ||
    tasks_coops="$(package_sh_list .package.sh pd_meta_tasks_coops \
      | lines_to_words )"
  ;;
    be* | proc* )
  ;;
    * ) error "tasks-load '$1'?" ;; esac ; shift ; done
}



htd_man_1__todo='Edit and mange todo.txt/done files.

  htd alias todo=tasks-edit

  htd todotxt-edit
  htd todotxt-tags
  htd todo-gtags

  htd todotxt tree
  htd todotxt list|list-all
  htd todotxt count|count-all
  htd todotxt edit

   todo-clean-descr
   todo-read-line

  htd build-todo-list
'

htd_als__todo=tasks-edit


htd_man_1__todotxt_edit='
  Edit task descriptions. Files do not need to exist. First two files default to
  todot.txt and .done.txt and will be created. "

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
  note "Acquired locks"
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
  test -n "$UCONFDIR" || error UCONFDIR 12
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
    tags ) shift 1; htd__todotxt_tags "$@" ;;
  esac
}


# The simplest tag (prj/ctx) scanner. Any non-zero argument is grepped for
# tags. Returns a unique sorted list. See tasks-hub
htd__todotxt_tags()
{
  while test -n "$1"; do
    test -s "$1" && {
      {
        grep -o '\(^\|\s\)+[A-Za-z0-9_][^\ ]*' $1 | words_to_lines
        grep -o '\(^\|\s\)@[A-Za-z0-9_][^\ ]*' $1 | words_to_lines
      } | sort -u
    }
  shift; done | sort -u | read_nix_style_file -
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
  . $UCONFDIR/git-remotes/$1.sh \
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
  test -d /srv/project-local || error "missing local project folder" 1
  test -d /srv/git-local || error "missing local git folder" 1

  htd__git_remote | while read repo
  do
    test -e /srv/git-local/$repo.git || warn "No src $repo" & continue
    test -e /srv/project-local/$repo || warn "No checkout $repo"
  done
}

# Create local bare in /src/
htd__git_init_src()
{
  test -d /srv/git-local || error "missing local git folder" 1

  htd__git_remote | while read repo
  do
    fnmatch "*annex*" "$repo" && continue
    test -e /srv/git-local/$repo.git || {
      git clone --bare $(htd git-remote $repo) /srv/git-local/$repo.git
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
htd_run__git_files=ia
htd__git_files()
{
  local pat="$(compile_glob $(lines_to_words $arguments.glob))"
  read_nix_style_file $arguments.repo | while read repo
  do
    cd $repo || continue
    # NOTE: only lists files at HEAD branch
    git ls-tree --full-tree -r HEAD | cut -d "  " -f 2 \
      | sed 's#^#'"$repo"':HEAD/#' | grep "$pat"
  done
}
htd_argsv__git_files=arg-groups-r
htd_arg_groups__git_files="repo glob"
htd_defargs_repo__git_files=/src/*.git


#
htd_man_1__git_grep='Run git-grep for every given repository, passing arguments
to git-grep. With `-C` interprets argument as shell command first, and passes
ouput as argument(s) to `git grep`. Defaults to `git rev-list --all` output
(which is no pre-run but per exec. repo). If env `repos` is provided it is used
iso. stdin. Or if `dir` is provided, each "*.git" path beneath that is used.
Else uses the arguments. If stdin is attach to the terminal, `dir=/src` is set.
Without any arguments it defaults to scanning all repos for "git.grep".'
htd_spc__git_grep='git-grep [ -C=REPO-CMD ] [ RX | --grep= ] [ GREP-ARGS | --grep-args= ] [ --dir=DIR | REPOS... ] '
htd__git_grep()
{
  set -- $(cat $arguments)
  test -n "$grep" || { test -n "$1" && { grep="$1"; shift; } || grep=git.grep; }
  test -n "$grep_args" -o -n "$grep_eval" || {
    trueish "$C" && {
      test -n "$1" && {
        grep_eval="$1"; shift; } ||
          grep_eval='$(git rev-list --all)';
    } || {
      test -n "$1" && { grep_args="$1"; shift; } || grep_args=master
    }
  }
  test "f" = "$stdio_0_type" -o -n "$repos" -o -n "$1" || dir=/src/
  note "Running ($(var2tags grep C grep_eval grep_args repos dir stdio_0_type))"
  htd_x__git_grep "$@" | { while read repo
    do
      {
        info "$repo:"
        cd $repo || continue
        test -n "$grep_eval" && {
          eval git --no-pager grep -il $grep $grep_eval || continue
        } || {
          git --no-pager grep -il $grep $grep_args || continue
        }
      } | sed 's#^.*#'$repo'\:&#'
    done
  }
  #| less
  note "Done ($(var2tags grep C grep_eval grep_args repos dir))"
}
htd_x__git_grep()
{
  test -n "$repos" && {
    debug "Repos: '$repos'"
    echo "$repos" | words_to_lines
  } || { test -n "$dir" && {
      for repo in $dir/*.git
        do
          echo $repo
        done
      noop
    } || { test -n "$1" && {
        while test $# -gt 0
        do
          echo "$1"
          shift
        done
        noop
      } || {
        cat -
      }
    }
  }
}
htd_run__git_grep=iAO


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
    for ext in $DOC_EXTS
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
    grep -qE "\<$p_\>" $1 || failed "$1: expected '$branch'"
  done
  exec 6<&-
  test -s "$failed" && {
    stderr failed "missing some branch references in '$1'"
  } || {
    rm "$failed"
    stderr ok "checked for and found references for all branches in '$1'"
  }
}
htd_als__gitflow_check=gitflow-check-doc


htd__gitflow_status()
{
  note "TODO: see gitflow-check-doc"
  defs gitflow.txt | \
    tree_to_table  | \
    while read base branch
    do
      git cherry $base $branch | wc -l
    done
}
htd_als__gitflow=gitflow-status


htd_man_1__source='Generic sub-commands dealing with source-code. For Shell
specific routines see also `function`.

  source lines FILE [ START [ END ]]        Copy (output) from line to end-line.
'
htd__source()
{
  test -n "$1" || set -- copy
  case "$1" in
    lines ) shift
        test -e "$1" || error "file expected '$1'" 1
        source_lines "$@" || return $?
      ;;
    copy ) shift
        htd__source lines "$3" "$1" "" "$2"
      ;;
    copy-where ) shift
        copy_where "$@"
      ;;
    cut-where ) shift
        cut_where "$@" || return $?
      ;;
    copy-paste ) shift
        test -z "$4" && cp_board=htd-source || cp=$4
        copy_only=false \
        copy_paste "$1" "$2" "$3" || return $?
        test -n "$4" || echo $cp
      ;;
    diff-where | sync-where ) shift
        diff_where "$@" || return $?
      ;;
    where-grep ) shift
        file_where_grep "$@" || return $?
        echo $line_number
      ;;
    where-grep-tail ) shift
        file_where_grep_tail "$@" || return $?
        echo $line_number
      ;;
    expand-sentinel ) shift
        where_line="$(grep -nF "# htd source copy-paste: $2" "$1")"
        line_number=$(echo "$where_line" | sed 's/^\([0-9]*\):\(.*\)$/\1/')
        test -n "$line_number" || return $?
        expand_sentinel_line "$1" $line_number || return $?
      ;;
    * ) error "'$1'?" 1
      ;;
  esac
}



htd_man_1__function='Operate on specific functions in Sh scripts.

   copy FUNC FILE
     Retrieves function-range and echo function including envelope.
   start-line
     Retrieve line-number for function.
   range
     Retrieve start- and end-line-number for function.
'
htd__function()
{
  test -n "$1" || set -- copy
  case "$1" in
    copy ) shift
        copy_function "$@" || return $?
      ;;
    start-line ) shift
        function_linenumber "$@" || return $?
        echo $line_number
      ;;
    range ) shift
        function_linerange "$@" || return $?
        echo $start_line $span_lines $end_line
      ;;
    * ) error "'$1'?" 1
      ;;
  esac
}


htd_man_1__expand_source_line='Replace a source line with the contents of the sourced script
  
This must be pointed to a line with format: 

  .\ (P<sourced-file>.*)
'
htd_spc__expand_source_line='expand-source-line FILE LINENR'
htd__expand_source_line()
{
  expand_source_line "$@"
}


htd_man_1__copy_paste_function='
  Remove function from source and place in seperately sourced file'
htd_spc__copy_paste_function='copy-paste-function [ --{,no-}copy-only ]'
htd__copy_paste_function()
{
  test -f "$1" -a -n "$2" -a -z "$3" || error "usage: FILE FUNC" 1
  copy_paste_function "$2" "$1"
  note "Moved function $2 to $cp"
}


htd_man_1__diff_function='
  Compare single function from Sh script, to manually sync/update related
  functions in different files/directories. Normally runs vimdiff on a synced
  file. But quiet instead exists, and copy-only does not modify the source
  script but only shows the diff.  Normally (!copy-only) the two functions are
  replaced by a source command to their temporary file used for comparison, 
  so that during editing the script remains fully functional.

  But meanwhile the both function versions are conveniently in separate files,
  for vimdiff or other comparison/sync tool.
'
htd_spc__diff_function="diff-func(tion) [ --quiet ] [ --copy-only ] [ --no-edit ] FILE1 FUNC1 DIR[FILE2 [FUNC2]] "
htd__diff_function()
{
  test -n "$1" -a -n "$2" -a -n "$3" || error "usage: $htd_spc__diff_function" 21
  test -n "$4" || {
    test -d "$3" -o -f "$3" || error "usage: $htd_spc__diff_function" 22
    test -f "$3" && {
      set -- "$1" "$2" "$3" "$2"
    } || {
      set -- "$1" "$2" "$3/$1" "$2"
    }
  }
  test -f "$1" -a -f "$3" || {
    stderr error "Missing files '$1' or '$3'"
    error "usage: $htd_spc__diff_function" 23
  }
  var_isset quiet || quiet=false
  var_isset sync || {
    trueish "$quiet" && sync=false || sync=true
  }
  var_isset edit || edit=$sync
  var_isset copy_only || {
    trueish "$sync" && copy_only=true || copy_only=false
  }
  cp_board= copy_paste_function "$2" "$1" || error "copy-paste-function 1" $?
  src1_line=$start_line
  src1=$cp
  cp_board= copy_paste_function "$4" "$3" || error "copy-paste-function 2" $?
  src2_line=$start_line
  src2=$cp
  trueish "$edit" && {
    diff -bqr $src1 $src2 >/dev/null 2>&1 &&
      stderr ok "nothing to do, '$2' in sync for '$1' $3'" || {
        vimdiff $src1 $src2 < /dev/tty &&
          stderr done "vimdiff ended" ||
          stderr error "vimdiff aborted, leaving unexpanded source lines" $?
      }
  } || {
    trueish "$quiet" && {
      diff -bqr $src1 $src2 >/dev/null 2>&1 && {
        stderr ok "in sync '$2'"
        echo "diff-function:$*" >> $passed
      } || {
        stderr warn "Not in sync '$2'"
        echo "diff-function:$*" >> $failed
      }
    } || {
      diff $src1 $src2
      stderr ok "'$2'"
    }
  }
  trueish "$quiet" || {
    diff -bqr $src1 $src2 >/dev/null 2>&1 &&
    stderr debug "synced '$*'" ||
    stderr warn "not in sync '$*'"
  }
  trueish "$copy_only" || {
    expand_source_line $1 $src1_line || error "expand-source-line 1" $?
    expand_source_line $3 $src2_line || error "expand-source-line 2" $?
  }
}
htd_run__diff_function=iAO
htd_als__diff_func=diff-function


htd_man_1__sync_function='Compare Sh functions using vimdiff. See diff-function,
this command uses:
  quiet=false copy-only=false edit=true diff-function $@
'
htd__sync_function()
{
  export quiet=false copy_only=false edit=true
  htd__diff_function "$@"
}
htd_run__sync_function=iAO


htd_man_1__diff_functions="List all functions in FILE, and compare with FILE|DIR

See diff-function for behaviour.
"
htd__diff_functions()
{
  test -n "$1" || error "diff-functions FILE FILE|DIR" 1
  test -n "$2" || set -- "$1" $scriptpath
  test -e "$2" || error "Directory or file to compare to expected '$2'" 1
  test -f "$2" || set -- "$1" "$2/$1"
  test -e "$2" || { error "Unable to get remote side for '$1'"; return 1; }
  test -z "$3" || error "surplus arguments: '$3'" 1
  htd__list_functions $1 |
        sed 's/\(\w*\)()/\1/' | sort -u | while read func
  do
    grep -bqr "^$func()" $1 || {
      warn "No function $func in $2"
      continue
    }
    htd__diff_function "$1" "$func" $1
  done
}
htd_run__diff_functions=iAO


htd_man_1__sync_functions='List and compare functions.

Direct diff-function to be verbose, cut functions into separate files, use
editor for sync and then restore both functions at original location.
'
htd__sync_functions()
{
  export quiet=false copy_only=false edit=true
  htd__diff_functions "$@"
}
htd_run__sync_functions=iAO


htd_man_1__diff_sh_lib='Look for local *.lib files, compare to same file in DIR.
  See diff-function for options'
htd_spc__diff_sh_lib='diff-sh-lib [DIR=$scriptpath]'
htd__diff_sh_lib()
{
  test -n "$1" || set -- $scriptpath
  test -d "$1" || error "Directory expected '$1'" 1
  test -z "$2" || error "surplus arguments: '$3'" 1
  list_functions_scriptname=false
  quiet=true
  for lib in *.lib.sh
  do
    note "Lib: $lib"
    htd__diff_functions $lib $1 || continue
  done
}
htd_run__diff_sh_lib=iAO



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


htd__push()
{
  test -n "$1" || error "domain ID expected"
  local id=$(domain id) current_branch=$( git name-rev --name-only HEAD )
  domain id $1
  {
    git push $(git config branch.${current_branch}.remote) $current_branch
  } || error "Unable to push"
  domain id $id
}


htd__recommit()
{
  test -z "$1" || {
    id=$(domain id)
    domain id $1
  }
  current_branch=$( git name-rev --name-only HEAD )
  {
    git add -u &&
      git ci --amend --reset-author &&
        git push $(git config branch.${current_branch}.remote) $current_branch
  }
  test -z "$1" || domain id $id
}


htd_man_1__push_commit="Commit modified files and push to default remote. "
htd_spc__push_commit='(pci|push-commit)
    [ [ --id ID ] [ --amend ] [ --all | --no-update ] ]
    [ --no-push | [ --any ] [ --every ] ]                 MSG [REMOTES]
'
htd__push_commit()
{
  # Argument handling
  # FIXME: could do away with half of subcmd code with better dependent env defaults
  {
    trueish "$verbose" || trueish "$DEBUG"
  } &&
    note "id=$id update=$update amend=$amend all=$all push=$push any=$any every=$every"
  # FIXME: losing quotation marks!!
  set -- "$(cat $arguments | lines_to_words )"
  test -n "$1" && { not_trueish "$amend" || {
      error "Commit message given and --amend '$*'" 1
    }; } || { not_falseish"$amend" || {
      error "Commit message expected" 1
    }; }

  var_isset update && {
    falseish "$update" && {
      trueish "$update" || error "unexpected value for update '$update'" 1
    } || {
      var_isset all && {
        falseish "$all" || error "--update and add --all are exclusive" 1
      }
    }
  } || {
    trueish "$all" && update=0 || update=1
  }
  var_isset push || push=true

  ## push-commit subcommand routine
  # Add modified files, or add all untracked files
  trueish "$update" && {
    git add -u || error "Failed adding modified files??" 1
  } || {
    trueish "$all" && {
      git add -a . || error "Unable to add all untracked" 1
    }
  }

  # Commit to local repository
  test -z "$id" || {
    # Switch ID if needed
    current_id="$(domain id)"
    test -n "$current_id" || error "Cannot get current domain ID" 1
    test "$current_id" = "$id" || {
      domain id $id || error "Domain ID switch from '$current_id' to '$id' failed" 1
    }
  }
  trueish "$amend" && {
    test -n "$id" && git_ci_f="--reset-author --amend" || git_ci_f="--amend"
  }
  test -z "$1" || git_ci_f="$git_ci_f -m \"$1\""
  eval git commit $git_ci_f &&
    note "Committted ('$git_ci_f')" ||
    error "Commit '$git_ci_f' failed" 1
  test -z "$id" || {
    domain id $current_id
  }
  shift

  # Distribute commit(s)
  current_branch=$( git name-rev --name-only HEAD )
  # More argument handling first
  test -n "$1" && {
    trueish "$every" ||
      warn "Remotes given and --every, remotes are not overriden"
  } || {
    trueish "$every" && {
      set -- $(git remote)
    } || {
      trueish "$push" && {
        # Set remote for current tracked branch
        set -- $(git config branch.${current_branch}.remote ||
          error "Unable to determine tracking remote of $current_branch branch" 1)
      }
    }
  }
  # Perform push
  trueish "$push" && {
    for remote in $@
    do
      trueish "$any" && {
        git push --all $remote || failed "$base:$subcmd:push-any:$remote"
      } || {
        git push $remote $current_branch || failed "$base:$subcmd:push:$remote"
      }
    done
  } || {
    test -n "$1" || {
      warn "Remotes given but --no-push is on [$*]"
    }
  }
}
htd_run__push_commit=iIAO
htd_als__pci=push-commit


htd_man_1__push_commit_all="Commit tracked files and push to everywhere. Add --any to push all branches too."
htd_spc__push_commit_all="(pcia|push-commit-all) [ --id ID ] [ --any ] MSG"
htd__push_commit_all()
{
  update=true every=true \
  htd__push_commit "$@"
}
htd_run__push_commit_all=iIAO
htd_als__pcia=push-commit-all


htd__archive_init()
{
  test -d "$CABINET_DIR" || {
    trueish "$interactive" || {
      sys_confirm "No local cabinet exists, created it? [yes/no]" || {
        warn "Cabinet folder missing ($CABINET_DIR)" 1
      }
      mkdir -vp $CABINET_DIR
    }
  }
  return 1
}

# Move path to archive path in htdocs cabinet
# XXX: see backup, archive-path
# $ archive [<prefix>]/[<datepath>]/[<id>] <refs>...
htd_spc__archive='archive REFS..'
htd__archive()
{
  test -d "$CABINET_DIR" || htd__archive_init
  test -n "$1" || warn "expected references to backup" 1
  while test $# -gt 0
  do
    htd_archive_path_format $CABINET_DIR $1
    shift
  done
}
htd_run__archive=ieAO
htd_argsv__archive()
{
  opt_args "$@"
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

htd_spc__save='save [ ( [PREFIX/]ID ) | PATHNAME [DESTPATH] ]'
# Save refs (download locators if not present) to prefix,
# building a full path for each ref from the prefix+ids+filetags.
# $ save "[<prefix>/]<id>" <refs>...
# TODO: define global <prefix> and <id> to correspond with (sets of) path instances
# ie. lookup given prefix and id first, see if it exists.
# XXX: may have lookup lookup. Use -g to override.
# <prefix>
htd__save()
{
  # TODO: fix the old save URL setup
  case "$1" in
    http*|magnet*|mailto* )
        htd__save_tags "$1"
        htd__save_url "$@"
      ;;
    * )
        req_file_arg "$1"
        test -n "$2" -o -d "$2" || error "expected directory argument '$2'" 1
        test -- "$1" "$bp/$bn"
        note "TODO: set target to journal, or cabinet"
        exit 1
        local bp="$(dirname "$1")" bn="$(basename "$1")"
        echo cp $1 $2/$bp/$bn
        echo "# See-Also: $new_ctxid $bp/$bn" >>$1
        htd_rewrite_comment Id From $2/$bp/$bn
        echo "# See-Also: $ctxid $bp/$bn" >>$2/$bp/$bn
        local new_ctxid=""
      ;;
  esac
}


htd__tags()
{
  test -n "$DBFILE" || DBFILE=~/.bookmarks.sqlite
echo
  sqlite3 $DBFILE <<SQL
    SELECT n2.\`name\`, n1.\`id\` FROM names n2, nodes n1
    JOIN names ON n2.id = n1.id ;
SQL
echo $?
echo
  exit $?
  sqlite3 $DBFILE <<SQL
    SELECT * FROM names_tag ;
SQL
  sqlite3 $DBFILE <<SQL
    SELECT nodes.\`id\`, names.\`name\`
    FROM
      names_tag,
      names,
      nodes
    JOIN names_tag ON names.id = names_tag.id
    JOIN names ON nodes.id = names.id ;
SQL
#  ORDER BY p.time DESC;
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


htd_man_1__package="
  Pretty print the Sh package settings. See package.rst.
"

htd__package()
{
  #test -z "$1" || export package_id=$1
  package_lib_load
  test -n "$1" && {
    # Turn args into var-ids
    _p_extra() { for k in $@; do mkvid "$k"; printf -- "$vid "; done; }
    _p_lookup() {
      . $PACKMETA_SH
      # See if lists are requested, and defer
      for k in $@; do
        package_sh_list_exists "$k" || continue
        package_sh_list $PACKMETA_SH $k
        shift
      done
      test -z "$*" ||
        map=package_ package_sh "$@"
    }
    echo "$(_p_lookup $(_p_extra "$@"))"

  } || {
    read_nix_style_file $PACKMETA_SH | while IFS='=' read key value
    do
      eval $LOG header2 "$(kvsep=' ' pretty_print_var "$key" "$value")"
    done
  }
}
htd_run__package=iAO


htd_man_1__topics_list='List topics'
htd__topics_list()
{
  cd $HTDIR
  local $(map=package_pd_meta_ext_topics_:topics_list_ \
    package_sh  id  roots )
  test -n "$topics_list_id" || error topic-list-id 1
  test -n "$topics_list_roots" || error topic-list-roots 1
  # TODO: topics personal/ web/ domain?
  find $topics_list_roots | htd pathnames | \
    grep -v 'Rules\|\/[^A-Z].*$' |
    grep -v '\.[A-Za-z0-9_-]*$'
}
htd_run__topics_list=iAO


htd__topics_save()
{
  test -n "$1" || error "Document expected" 1
  test -e "$1" || error "No such document $1" 1
  htd__tpaths "$1" | while read path
  do
    echo
  done
}


create_topics()
{
# TODO: htd create-topics
#topic get $(basename $1) ||
#topic get $(basename $1) ||
  topic new $(basename $1) $(basename $(dirname $1))
}


htd__topics_commit()
{
  htd__topics | while read topic_path
  do
    topic get $(basename $topic_path) || create_topics $topic_path
  done
}


htd__topics_persist()
{
  while read topic_id topic_name topic_path
  do
    mkdir -vp $HTDIR/$topic_path
    mkdir -vp $HTDIR/$topic_path
  done
}



htd_man_1__run_names="List local package script names"
htd_run__run_names=f
htd__run_names()
{
  jsotk.py keys -O lines $PACKMETA_JS_MAIN scripts
}


htd_man_1__run_dir="List local package script names and lines"
htd_run__run_dir=fp
htd__run_dir()
{
  htd__run_names | while read name
  do
    printf -- "$name\n"
    verbose_no_exec=1 htd__run $name
  done
}


htd_man_1__ls="List local package names"
htd_run__ls=f
htd__ls()
{
  PACKMETA="$(cd "$1" && echo package.y*ml | cut -f1 -d' ')"
  jsotk.py -I yaml -O py objectpath $PACKMETA '$.*[@.id is not None].id'
}


htd_man_1__run="Run scripts from package"
htd__run()
{
  test -n "$1" || set -- scripts

  # Update local package
  local metaf=

  . $PACKMETA_SH

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

  # Execute script-lines
  (
    run_scriptname="$1"
    shift
    SCRIPTPATH=
    unset Build_Deps_Default_Paths
    ln=0

    test -z "$package_cwd" || {
      note "Moving to '$package_cwd'"
      cd $package_cwd
    }
    test -z "$package_env" || {
      eval $package_env
    }
    package_sh_script "$run_scriptname" | while read scriptline
    do
      export ln=$(( $ln + 1 ))
      not_trueish "$verbose_no_exec" && {
        stderr info "Scriptline: '$scriptline'"
      } || {
        printf -- "\t$scriptline\n"
        continue
      }
      (

        eval "$scriptline"

      ) && continue || {
          echo "$run_scriptname:$ln: '$scriptline'" >> $failed
          error "At line $ln '$scriptline' for '$run_scriptname'" $?
        }
      # NOTE: execute scriptline with args only once
      set --
    done
  )
  trueish "$verbose_no_exec" && return || stderr notice "'$1' completed"
}
htd_run__run=iAOp


htd_man_1__list_run="list lines for package script"
htd__list_run()
{
  verbose_no_exec=1 \
    htd__run "$@"
}
htd_run__list_run=iAO


htd_man_1__rules='
  edit
    Edit the HtD rules file.
  show
    Resolve and show HtD rules with Id, Cwd and proper Ctx.
  status
    Show Id and last status for each rule.
  run [ Target-Grep [ Cmd-Grep ] ]
    Evalute all rules and update status and targets. Rule selection arguments
    like `each`. 
  ids [ Target-Grep [ Cmd-Grep ] ]
    Resolve rules and list IDs generated from the command, working dir and context.
  foreach 
  each [ Target-Grep [ Cmd-Grep ] ]
    Parse rules to key/values, filter on values using given Grep patterns.
  id
  env-id
  parse-ctx
  eval-ctx
'
htd__rules()
{
  test -n "$htd_chatter" || htd_chatter=$verbosity
  test -n "$htd_rule_chatter" || htd_rule_chatter=3
  test -n "$1" || set -- table
  case "$1" in

    edit )                        htd__edit_rules || return  ;;
    table ) shift ;               raw=true htd__show_rules "$@" || return  ;;
    show ) shift ;                htd__show_rules "$@" || return  ;;
    status ) shift ;              htd__period_status_files "$@" || return ;;
    run ) shift ;                 htd__run_rules "$@" || return ;;
    ids ) shift ;                 htd__rules foreach "$1" "$2" id || return ;;
    foreach ) shift
        test -n "$*" || set -- 'local\>' "" id
        htd__rules each "$1" "$2" | while read vars
        do
          local package_id= ENV_NAME= htd_rule_id=
          line= row_nr= CMD= RT= TARGETS= CWD= CTX=
          eval "$vars"
          htd__rules pre-proc "$vars" || continue
          htd__rules "$3" "$vars" ||
            error "Running '$3' for $row_nr: '$line' ($?)"
          continue
        done
      ;;
    each ) shift
        # TODO: use optparse instead test -z "$1" || local htd_rules=$1 ; shift
        fixed_table $htd_rules CMD RT TARGETS CTX | {
          case " $* " in
            " "[0-9]" "|" "[0-9]*[0-9]" " ) grep "row_nr=$1\>" - ;;
            * ) { test -n "$2" &&
                  grep '^.*\ CMD=\\".*'"$2"'.*\\"\ \ RT=.*$' - || cat -
              } | { test -n "$1" &&
                  grep '^.*\ TARGETS=\\".*'"$1"'.*\\"\ \ CTX=.*$' - || cat -
              } ;;
          esac
        }
      ;;
    id ) shift
        case " $* " in
          " "[0-9]" "|" "[0-9]*[0-9]" " )
              vars="$(eval echo "$(htd__rules each $1)")"
              line= row_nr= CMD= RT= TARGETS= CWD= CTX=
              set -- "$vars"
              eval export "$@"
              verbosity=$htd_chatter
              htd__rules parse-ctx "$*" || return
              local package_id= ENV_NAME= htd_rule_id=
              htd__rules eval-ctx "$vars" || return
            ;;
          *" CMD="* ) # from given vars
              line= row_nr= CMD= RT= TARGETS= CWD= CTX=
              vars="$@"
              verbosity=$htd_rule_chatter eval export "$vars"
              verbosity=$htd_chatter
            ;;
          * ) # Cmd Ret Targets Ctx
              line= row_nr= CMD="$1" RT="$2" TARGETS="$3" CWD="$4" CTX="$5"
              vars="CMD=\"$1\" RT=\"$2\" TARGETS=\"$3\" CWD=\"$4\" CTX=\"$5\""
            ;;
        esac
        test -z "$DEBUG" ||
          note "$row_nr: CMD='$CMD' RET='$RT' CWD='$CWD' CTX='$CTX'"
        htd__rules env-id || return
      ;;
    env-id ) shift
        test -n "$htd_rule_id" || { local sid=
          test -n "$package_id" && {
              mksid "$CWD $package_id $CMD"
            } || {
              test -n "$ENV_NAME" && {
                mksid "$CWD $ENV_NAME $CMD"
              } || {
                mksid "$CWD $CMD"
              }
            }
            htd_rule_id=$sid
          }
          echo $htd_rule_id
      ;;
    parse-ctx ) shift
        test -n "$CTX" || {
          ctx_var="$(echo "$vars" | sed 's/^.*CTX="\([^"]*\)".*$/\1/')"
          warn "Setting CWD to root, given empty '$ctx_var' env. "
          CTX=/
        }
        CWD=$(echo $CTX | cut -f1 -d' ')
        test -d "$CWD" && CTX=$(echo $CTX | cut -c$(( ${#CWD} + 1 ))- ) || CWD=
      ;;
    eval-ctx ) shift
        test -n "$CTX" -a -n "$CWD" -a \( \
          -n "$package_id" -o -n "$htd_rule_id" -o "$ENV_NAME" \
        \) || {
          # TODO: alternative profile locations, config/tools/env.sh,
          # .local/etc , ~/.conf
          test -e "$HOME/.local/etc/profile.sh" && CTX="$CTX . $HOME/.local/etc/profile.sh"
        }
        test -n "$CTX" && {
          verbosity=$htd_rule_chatter eval $CTX
          verbosity=$htd_chatter
        }
        test -n "$CWD" || {
          ctx_var="$(echo "$*" | sed 's/^.*CTX="\([^"]*\)".*$/\1/')' env"
          warn "Setting CWD to root, given '$ctx_var' ctx"
          CWD=/
        }
      ;;

    pre-proc ) shift
        htd__rules parse-ctx "$vars" || {
          error "Parsing ctx at $row_nr: $ctx" && continue ; }
        htd__rules eval-ctx "$vars" || {
          error "Evaluating ctx at $row_nr: $ctx" && continue ; }
        # Get Id for rule
        htd_rule_id=$(htd__rules env-id "$vars")
        test -n "$htd_rule_id" || {
          error "No ID for $row_nr: '$line'" && continue ; }
        return 0

        # TODO: to run rules, first get metadata for path, like max-age
        # In this case, metadata like ck-names might provide if matched with a
        # proper datatype chema
        htd__tasks_buffers $TARGET "$@" | while read buffer
        do test -e "$buffer" || continue; echo "$buffer"; done

        target_files= targets= max_age=
        #targets="$(htd__prefix_expand $TARGETS "$@")"
        #are_newer_than "$targets" $max_age && continue
        #sets_overlap "$TARGETS" "$target_files" || continue
        #for target in $targets ; do case "$target" in

        #    p:* )
        #        #test -e "$(statusdir.sh file period ${target#*:})" && {
        #        #  echo "TODO 'cd $CWD;"$CMD"' for $target"
        #        #} || error "Missing period for $target"
        #      ;;

        #    @* ) echo "TODO: run at context $target"; continue ;;

        #  esac
        #done
        test -z "$DEBUG" ||
          $LOG ok pre-proc "CMD=$CMD RT=$RT TARGETS=$TARGETS CWD=$CWD CTX=$CTX"
      ;;

    update | post-proc ) shift
        test -n "$3" || set -- "$1" "$2" 86400
        # TODO: place record in each context. Or rather let backends do what
        # they want with the ret/stdout/stderr.
        note "targets: '$TARGETS'"
        for target in $TARGETS
        do
          scr="$(htd__tasks_buffers "$target" | grep '\.sh$' | head -n 1)"
          test -n "$scr" ||
              error "Error lookuping backend for target '$target'" 1
          test -x "$scr" || { warn "Disabled: $scr"; continue; }
          note "$target($scr): Status $RT, $CMD $CWD $CTX"
        done
        note "TODO record $1: $2 $3"
        #test -e "$stdout" -o -e "$stderr" ||
        #note "Done: $(filesize $stdout $stderr) $(filemtype $stdout $stderr)"
      ;;

    * ) error "'$1'? 'rules $*'"
      ;;
  esac
}
htd_grp__rules=htd-rules
#htd_als__edit_rules='rules edit'
htd__edit_rules()
{
  $EDITOR $htd_rules
}
htd_grp__edit_rules=htd-rules
#htd_als__id_rules='rules id'
#htd_als__env_rules='rules id'


# htdoc rules development documentation in htdocs:Dev/Shell/Rules.rst
# pick up with config:rules/comp.json and build `htd comp` aggregate metadata
# and update statemachines.
#
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
htd_grp__period_status_files=htd-rules


# Run either when arguments given match a targets, or if any of the linked
# targets needs regeneration.
# Targets should resolve to a path, and optionally a maximum age which defaults
# to 0.
#
htd__run_rule()
{
  line= row_nr= CMD= RT= TARGETS= CWD= CTX=
  local package_id= ENV_NAME= htd_rule_id= vars="$1"
  eval local "$1"
  htd__rules pre-proc "$var" || {
    error "Parsing ctx at $row_nr: $ctx" && continue ; }
  note "Running '$htd_rule_id'..."
  local stdout=$(setup_tmpf .stdout) stderr=$(setup_tmpf .stderr)
  R=0 ; {
    cd $CWD # Home if empty
    htd__rules eval-ctx || { error "Evaluating $ctx" && continue ; }
    test -n "$CMD" || { error "Command required" && continue; }
    test -n "$CWD" || { error "Working dir required" && continue; }
    #test -n "$ENV_NAME" || { error "Env profile required" && continue; }
    note "Executing command.."
    ( cd $CWD && $CMD 2>$stderr >$stdout )
  } || { R=$?
    test "$R" = "$RT" || warn "Unexpected return from rule exec ($R)"
  }
  test "$RT" = "0" || {
    test "$R" = "$RT" && 
      note "Non-zero exit ignored by rule ($R)" ||
        warn "Unexpected result $R, expected $RT"
  }
  htd__rules post-proc $htd_rule_id $R
  rm $stdout $stderr 2>/dev/null
  return $R
}

htd__run_rules()
{
  test -n "$1" || set -- '@local\>'
  htd__rules each "$1" "$2" | while read vars ; do
    htd__run_rule "$vars"
    continue
  done
}
htd_grp__run_rules=htd-rules


htd__show_rules()
{
  # TODO use optparse htd_host_arg
  upper=0 default_env out-fmt plain
  upper=0 default_env raw false
  trueish "$raw" && {
    test -z "$*" || error "Raw mode does not accept filter arguments" 1
    local cutf= fields="$(fixed_table_hd_ids "$htd_rules")"
    fixed_table_cuthd "$htd_rules" "$fields"
    cat $htd_rules | case "$out_fmt" in
      txt|plain|text ) cat - ;;
      csv )       out_fmt=csv   htd__table_reformat - ;;
      yml|yaml )  out_fmt=yml   htd__table_reformat - ;;
      json )      out_fmt=json  htd__table_reformat - ;;
      * ) error "Unknown format '$out_fmt'" 1 ;;
    esac
  } || {
    local fields="Id Nr CMD RT TARGETS CWD CTX line"
    test "$out_fmt" = "csv" && { echo "#"$fields | tr ' ' ',' ; }
    htd__rules each "$@" | while read vars
    do
      line= row_nr= CMD= RT= TARGETS= CWD= CTX=
      local package_id= ENV_NAME= htd_rule_id=
      {
        eval local "$vars" && htd__rules pre-proc "$var"
      } || {
        error "Resolving context at $row_nr ($?)" && continue
      }
      case "$out_fmt" in
        txt|plain|text ) printf \
            "$htd_rule_id: $CMD <$CWD> [$CTX] ($RT) $TARGETS <$htd_rules:$row_nr>\n"
          ;;
        csv ) printf \
            "$htd_rule_id,$row_nr,\"$CMD\",$RT,\"$TARGETS\",\"$CWD\",\"$CTX\",\"$line\"\n"
          ;;
        yml|yaml ) printf -- "- nr: $row_nr\n  id: $htd_rule_id\n"\
"  CMD: \"$CMD\"\n  RT: $RT\n  CWD: \"$CWD\"\n  CTX: \"$CTX\"\n"\
"  TARGETS: \"$TARGETS\"\n  line: \"$line\"\n"
          ;;
        json ) test $row_nr -eq 1 && printf "[" || printf ",\n"
          printf "{ \"id\": \"$htd_rule_id\", \"nr\": $row_nr,"\
" \"CMD\": \"$CMD\", \"RT\": $RT, \"TARGETS\": \"$TARGETS\","\
" \"CWD\": \"$CWD\", \"CTX\": \"$CTX\", \"line\": \"$line\" }"
          ;;
        * ) error "Unknown format '$out_fmt'" 1 ;;
      esac
    done
    test "$out_fmt" = "json" && { echo "]" ; } || noop
  }
}
htd_of__show_rules='plain csv yaml json'
htd_grp__show_rules=htd-rules


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
htd_grp__rule_traget=htd-rules


htd_man_1__storage=''
htd_spc__storage='storage TAG ACTION'
htd__storage()
{
  test -n "$2" || set -- "$1" process
  eval $(package_sh id lists_default)
  test -n "$*" || { set -- $lists_default; note "Setting default tag args '$*'"; }
  while test $# -gt 0
  do
    local scr= cb= be=
    htd__get_backend "$1" store/ $2 || {
      stderr debug "Skipping non-storage '$1'"; shift 2; continue; }
    note "Processing for '$1':"; $cb ; shift 2
  done
}
htd_run__storage=Ap
htd_argsv__storage=htd_argsv__tasks_session_start
htd_grp__storage=htd-rules


htd__get_backend()
{
  test -n "$2" || set -- "$1" "store/" "$3"
  test -n "$3" || set -- "$1" "$2" "stat"
  case "$1" in
    @* ) ctx=$(echo "$1" | cut -c2- ) ; be=at-$ctx
      ;;
    +* ) ctx=$(echo "$1" | cut -c2- ) ; be=in-$ctx
      ;;
    * ) error "get-backend '$1'?" 1 ;;
  esac
  mksid $be
  scr=$( htd__extensions $2$sid )
  test -n "$scr" || return 1
  mkvid ${be}__${3} ; cb=${vid} ; . $scr ; func_exists $cb
}
htd_grp__get_backend=htd-rules


htd__extensions()
{
  lookup_test="test -x" lookup_path HTD_EXT $1.sh
}
htd_grp__process=htd-rules


htd_man_1__process='Process each item in list.
  name.list
  to/see.list
  @Task
  +proj:id.path
  @be.path
'
htd_spc__process='process [ LIST [ TAG.. [ --add ] | --any ]'
htd_env__process='
  todo_slug= todo_document= todo_done=
'
htd__process()
{
  tags="$(htd__tasks_tags "$@" | lines_to_words ) $tags"
  note "Tags: '$tags'"
  htd__tasks_buffers $tags | grep '\.sh$' | while read scr
  do
    test -e "$scr" || continue
    test -x "$scr" || { warn "Disabled: $scr"; continue; }
  done
  for tag in $tags
  do
    scr="$(htd__tasks_buffers "$tag" | grep '\.sh$' | head -n 1)"
    test -n "$scr" -a -e "$scr" || continue
    test -x "$scr" || { warn "Disabled: $scr"; continue; }

    echo tag=$tag scr=$scr
    #grep $tag'\>' $todo_document | $scr
    # htd_tasks__at_Tasks process line
    continue
  done
}
htd_run__process=eA
htd_argsv__process=htd_argsv__tasks_session_start
htd_als__proc=process
htd_grp__process=htd-proc


htd__tab2csv()
{
  out_fmt=csv htd__table_reformat "$1"
}

htd__tab2json()
{
  out_fmt=json htd__table_reformat "$1"
}

htd__tab2yaml()
{
  out_fmt=yml htd__table_reformat "$1"
}

htd_als__tab_out=table-reformat
htd_of__table_reformat="csv yaml json"
htd__table_reformat()
{
  test -n "$1" || set -- -
  test -n "$fields" || {
    test "$1" != "-" || error "file needed to determine header fields" 1
    local fields="$(fixed_table_hd_ids "$1")"
  }
  test -n "$cutf" || fixed_table_cuthd "$1" "$fields" 
  upper=0 default_env out-fmt json
  test "$out_fmt" = "csv" && { echo "#"$fields | tr ' ' ',' ; }
  fixed_table "$1" $cutf | while read vars
  do
    set -- $fields ; eval $vars ; case "$out_fmt" in
      yml|yaml|json )
          printf -- "- "
          while test $# -gt 1
          do
            eval printf -- \"$1: \'\$$1\'\\n\ \ \"
            shift
          done
          eval printf -- \"$1: \'\$$1\'\\n\"
          shift
        ;;

      csv )
          while test $# -gt 1
          do
            eval printf -- \"\$$1',"'
            shift
          done
          eval printf -- \"\$$1'\\n"'
          shift
        ;;

      * ) error "Unknown format '$out_fmt'" 1 ;;
    esac
  done | {
    test "$out_fmt" = "json" && jsotk -Iyaml -Ojson - || cat -
  }
}

htd__table()
{
  test -n "$1" || set -- list
  case "$1" in
    list ) shift ;
      ;;
    reformat ) shift;   htd__table_reformat "$@" || return ;;
    * ) error "'$1'? 'table $*'"
      ;;
  esac
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
htd_grp__name_tags_all=htd-meta


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
htd_grp__update_checksums=htd-meta


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
htd_grp__ck=htd-meta
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

htd_grp__ck_init=htd-meta
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
htd_grp__ck_table=htd-meta
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
htd_grp__ck_table_subtree=htd-meta
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


htd_grp__ck_update=htd-meta
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

htd_grp__ck_drop=htd-meta
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

htd_grp__ck_validate=htd-meta
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
htd_spc__cksum="cksum [<table-file>]"
htd_grp__cksum=htd-meta

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
htd_grp__ck_prune=htd-meta

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
htd_grp__ck_consolidate=htd-meta

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
htd_grp__ck_clean=htd-meta

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
htd_grp__ck_metafile=htd-meta


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
htd_grp__ck_torrent=htd-media


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
htd_grp__mp3_validate=htd-media


htd__mux()
{
  test -n "$1" || set -- "docker-"
  test -n "$2" || set -- "$1" "dev"
  test -n "$3" || set -- "$1" "$2" "$(hostname -s)"

  note "tmuxinator start $1 $2 $3"
  tmuxinator start $1 $2 $3
}
htd_grp__mux=tmux


htd_man_1__tmux_sockets='List sockets of tmux servers. Each server is a separate
env with sessions and windows. '
htd__tmux_sockets()
{
  test -n "$1" || set NAME
  {
    lsof -U | grep '^tmux'
  } | {
      case "$1" in
      COMMAND ) awk '{print $1}' ;;
      PID ) awk '{print $2}' ;;
      USER ) awk '{print $3}' ;;
      FD ) awk '{print $4}' ;;
      TYPE ) awk '{print $5}' ;;
      DEVICE ) awk '{print $6}' ;;
      #NODE ) awk '{print $8}' ;;
      NAME )
          awk '{print $8}'
          awk '{print $9}'
        ;;
    esac
  } | sort -u
}
htd_grp__tmux_sockets=tmux


htd__tmux_list_sessions()
{
  test -n "$1" || set -- $(htd__tmux_sockets)
  while test $# -gt 0
  do
    test -e "$1" && {
      note "Listing for '$1'"
      tmux -S "$1" list-sessions
    } || {
      error "Given socket does not exists: '$1'"
    }
    shift
  done
}
htd_als__tmux_list=tmux-list-sessions
htd_als__tmux_sessions=tmux-list-sessions
htd_grp__tmux_list_sessions=tmux


htd_man_1__tmux_session_list_windows='List window names for current
socket/session. Note these may be empty, but alternate formats can be provided,
ie. "#{window_index}". '
htd_spc__tmux_session_list_windows='tmux-session-list-windows [ - | MATCH ] [ FMT ]'
htd__tmux_session_list_windows()
{
  test -n "$1" || set -- "$HTD_TMUX_DEFAULT_SESSION"
  test -n "$3" || set -- "$1" "$2" "#{window_name}"
  test -z "$4" || error "Surplus arguments '$4'" 1
  tmux_env_req 0
  $tmux list-windows -t "$1" -F "$3" | {
    case "$2" in
      "" )
          while read name
          do
            note "Window: $name"
          done
        ;;
      "-" ) cat ;;
      * )
          eval grep -q "'^$2$'"
        ;;
    esac
  }
}
htd_als__tmux_windows=tmux-session-list-windows
htd_als__tmux_session_windows=tmux-session-list-windows
htd_grp__tmux_session_list_windows=tmux


tmux_env_req()
{
  default_env TMux-SDir /opt/tmux-socket
  test -n "$TMUX_SOCK" && {
    debug "Using TMux-Sock env '$TMUX_SOCK'"
  } || {
    test -d "$TMUX_SDIR" || mkdir -vp $TMUX_SDIR
    # NOTE: By default have one server per host. Add Htd-TMux-Env var-names
    # for distinct servers based on currnet shell environment.
    default_env Htd-TMux-Env hostname
    TMUX_SOCK_NAME="htd$( for v in $HTD_TMUX_ENV; do eval printf -- \"-\$$v\"; done )"
    export TMUX_SOCK=$TMUX_SDIR/tmux-$(id -u)/$TMUX_SOCK_NAME
    falseish "$1" || {
      test -S  "$TMUX_SOCK" ||
        error "No tmux socket $TMUX_SOCK_NAME (at '$TMUX_SOCK')" 1
    }
    debug "Set TMux-Sock env '$TMUX_SOCK'"
  }
  tmux="tmux -S $TMUX_SOCK "
}



htd_man_1__tmux_get='Look for session/window with current selected server and
attach. The default name arguments may dependent on the env, or default to
Htd/bash. Set TMUX_SOCK or HTD_TMUX_ENV+env to select another server, refer to
tmux-env doc.'
htd_spc__tmux_get='tmux get [SESSION-NAME [WINDOW-NAME [CMD]]]'
htd__tmux_get()
{
  test -n "$1" || set -- "$HTD_TMUX_DEFAULT_SESSION" "$2" "$3"
  test -n "$2" || set -- "$1" "$HTD_TMUX_DEFAULT_WINDOW" "$3"
  test -n "$2" || set -- "$1" "$2" "$HTD_TMUX_DEFAULT_CMD"
  test -z "$4" || error "Surplus arguments '$4'" 1
  tmux_env_req 0

  # Look for running server with session name
  {
    test -e "$TMUX_SOCK" &&
      $tmux has-session -t "$1" >/dev/null 2>&1
  } && {
    info "Session '$1' exists"
    logger "Session '$1' exists"
    # See if window is there with session
    htd__tmux_session_list_windows "$1" "$2" && {
      info "Window '$2' exists with session '$1'"
      logger "Window '$2' exists with session '$1'"
    } || {
      $tmux new-window -t "$1" -n "$2" "$3"
      info "Created window '$2' with session '$1'"
      logger "Created window '$2' with session '$1'"
    }
  } || {
    # Else start server/session and with initial window
    eval $tmux new-session -d -s "$1" -n "$2" "$3" && {
      note "Started new session '$1'"
      logger "Started new session '$1'"
    } || {
      warn "Failed starting session '$1' ($?)"
      logger "Failed starting session '$1' ($?)"
    }
    # Copy env to new session
    for var in TMUX_SOCK $HTD_TMUX_ENV
    do
      $tmux set-environment -g $var "$(eval printf -- \"\$$var\")"
    done
  }
  test -n "$TMUX" || {
    note "Attaching to session '$1'"
    $tmux attach
  }
}
htd_grp__tmux_get=tmux



# Shortcut to create window, if not exists
# htd tmux-winit SESSION WINDOW DIR CMD
htd__tmux_winit()
{
  tmux_env_req 0
  ## Parse args
  test -n "$1" || error "Session <arg1> required" 1
  test -n "$2" || error "Window <arg2> required" 1
  # set window working dir
  test -e $UCONFDIR/script/htd/tmux-init.sh &&
    . $UCONFDIR/script/htd/tmux-init.sh || error TODO 1
  test -n "$3" || {
    set -- "$@" "$(htd_uconf__tmux_init_cwd "$@")"
  }
  test -d "$3" || error "Expected <arg3> to be directory '$3'" 1
  test -n "$4" || {
    # TODO: depending on context may also want to update or something different
    set -- "$1" "$2" "$3" "htd status"
  }
  $tmux list-sessions | grep -q '\<'$1'\>' || {
    error "No session '$1'" 1
  }
  $tmux list-windows -t $1 | grep -q $2 && {
    note "Window '$1:$2' already initialized"
  } || {
    $tmux new-window -t $1 -n $2
    $tmux send-keys -t $1:$2 "cd $3" enter "$4" enter
    note "Initialized '$1:$2' window"
  }
}
htd_grp__tmux_winit=tmux


htd__tmux_init()
{
  test -n "$1" || error "session name required" 1
  test -n "$2" || set -- "$1" "bash"
  test -z "$4" || error "surplus arguments: '$4'" 1
  tmux_env_req 0
  # set window working dir
  test -e $UCONFDIR/script/htd/tmux-init.sh &&
    . $UCONFDIR/script/htd/tmux-init.sh || error TODO 1
  test -n "$3" || {
    set -- "$@" "$(htd_uconf__tmux_init_cwd "$@")"
  }
  out=$(setup_tmpd)/htd-tmux-init-$$
  $tmux has-session -t "$1" >/dev/null 2>&1 && {
    logger "Session $1 exists"
    note "Session $1 exists"
  } || {
    $tmux new-session -dP -s "$1" "$2" && {
    #>/dev/null 2>&1 && {
      note "started new session '$1'"
      logger "started new session '$1'"
    } || {
      warn "Failed starting session '$1' ($?) ($out):"
      logger "Failed starting session '$1' ($?) ($out):"
      printf "Cat ($out) "
    }
    test ! -e "$out" || rm $out
  }
}
htd_grp__tmux_init=tmux


# Find a server with session name and CS env tag, and get a window
htd__tmux_cs()
{
  test -n "$1" || set -- Htd-$CS "$2" "$3"
  test -n "$2" || set -- "$1" 0    "$3"
  test -n "$3" || set -- "$1" "$2" ~/work
  (
    # TODO: hostname, session/socket tags
    export TMUX_SOCK_NAME=boreas-$1-term
    tmux_env_req 0
    htd__tmux_init "$1" "$SHELL" "$3"
    htd__tmux_winit "$@"
    $tmux set-environment -g CS $CS
    test -n "$TMUX" || $tmux attach
  )
}
htd_grp__tmux_cs=tmux


htd_man_1__tmux='Unless tmux is running, get a new tmux session, based on the
current environment.

Untmux is running with an environment matching the current, attach. Different
tmux environments are managed by using seperate sockets per session.

Start tmux, tmuxinator or htd-tmux with given names.
TODO: first deal with getting a server and session. Maybe later per window
management.
'
htd_spc__tmux=
htd__tmux()
{
  tmux_env_req 0
  test -n "$1" || set -- get

  case "$1" in
    list | sockets ) shift ; htd__tmux_sockets "$@" || return ;;
    list-sessions ) shift ; htd__tmux_list_sessions "$@" || return ;;
    list-windows ) shift ; htd__tmux_session_list_windows "$@" || return ;;
    * ) local c=$1; shift ; htd__tmux_$c "$@" || return ;;
  esac

  #while test -n "$1"
  #do
  #  func="htd__tmux_$(echo $1 | tr 'A-Z' 'a-z')"
  #  fname="$(echo "$1" | tr 'A-Z' 'a-z')"

  #  $tmux has-session -t $1 >/dev/null 2>&1 && {
  #    info "Session $1 exists"
  #    shift
  #    continue
  #  }

  #  func_exists "$func" && {

  #    # Look for init subcmd to setup windows
  #    note "Starting Htd-TMux $1 (tmux-$fname) init"
  #    try_exec_func "$func" || return $?

  #  } || {
  #    test -f "$UCONFDIR/tmuxinator/$fname.yml" && {
  #      note "Starting tmuxinator '$1' config"
  #      htd__mux $1 &
  #    } || {
  #      note "Starting Htd-TMux '$1' config"
  #      htd__tmux_init $1
  #    }
  #  }
  #  shift
  #done

}
htd_grp__tmux=tmux



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


htd_man_1__test="Run PDir tests in HTDIR"
htd__test()
{
  req_dir_env HTDIR
  cd $HTDIR && projectdir.sh test
}
htd_als___t=test
htd_grp__edit_test=htd-project


htd_man_1__edit_test="Edit all BATS spec-files (test/*-spec.bats)"
htd__edit_test()
{
  $EDITOR ./test/*-spec.bats
}
htd_als___T=edit-test
htd_grp__edit_test=htd-doc


htd_man_1__inventory="Edit all inventories"
htd__inventory()
{
  req_dir_env HTDIR
  test -e "$HTDIR/personal/inventory/$1.rst" && {
    set -- "personal/inventory/$1.rst" "$@"
  } || {
    set -- "personal/inventory/main.rst" "$@"
  }
  htd_rst_doc_create_update $1
  htd_edit_and_update $@
}
htd_als__inv=inventory
htd_grp__inventory=htd-doc


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
htd_grp__inventory_electronics=htd-doc



htd__disk()
{
  test -e /proc || error "proc required" 1
  case "$1" in

    -partitions ) shift
  tail -n +3 /proc/partitions | awk '{print $'$1'}'
      ;;

    -mounts )
        cat /proc/mounts | cut -d ' ' -f 2
      ;;

    -tab )
        sudo file -s /var/lib/docker/aufs
  tail -n +3 /proc/partitions | while read major minor blocks dev_node
  do
    echo $dev_node
    sudo file -s /dev/$dev_node
    grep '^/dev/'$dev_node /proc/mounts
  done
      ;;

    * ) error "? 'disk $*'" 1 ;;
  esac
}

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
  req_dir_env HTDIR
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
  gcal.py --version || return
  read_nix_style_file $UCONFDIR/google/cals.tab | while read calId summary
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


htd_man_1__jrnl_times='
    list-day PATH
        List times found in log-entry at PATH.
    list-tri*
        List times for +/- 1 day (by alias).
    list-days TODO
    list-weeks TODO
    list-dir Date-Prefix
    TODO: list (-1) (+1) (dir|days|weeks)
    to-cal
'
htd__jrnl_times()
{
  cd $HTDIR
  htd__today personal/journal
  case "$1" in

    list-day )
        test -e $2 && sed -n 's/.*\[\([0-9]*:[0-9]*\)\].*/\1/gp' $2
      ;;

    list-tri* | list-triune )
        for p in personal/journal/today.rst personal/journal/tomorrow.rst \
          personal/journal/yesterday.rst
        do
          # Prefix date (from real filename), and (symbolic) filename
          htd__jrnl_times list-day $p |
            sed "s#^#$(basename $(readlink $p) .rst) #g" |
            sed "s#^#$p #g"
        done
      ;;

    list-days )
        note "TODO: $*"
      ;;
    list-weeks )
        note "TODO: $*"
      ;;

    list-dir )
        for p in personal/journal/$2[0-9]*.rst
        do
          # Prefix date (from real filename), and (symbolic) filename
          htd__jrnl_times list-day $p |
            sed "s#^#$(basename $p .rst) #g" |
            sed "s#^#$p #g"
        done
      ;;

    list )
        test -n "$2" || set -- "$1" -1 +1 days
        test -n "$4" || set -- "$1" "$2" "$3" days
        case "$4" in
          dir )
              htd__jrnl_times list-dir "$2"
            ;;
          days )
              test "$2" = "-1" -a "$3" = "+1" &&
                htd__jrnl_times list-triune || htd__jrnl_times list-days "$2"
            ;;
          weeks )
              htd__jrnl_times list-week "$2"
            ;;
        esac
      ;;

    to-cal )
        # TODO: SCRIPT-MPE-4 cut down on events. e.g. put in 15min or 30min
        # bins. Add hyperlinks for sf site. And create whole-day event for days
        # w. journal entry without specific times
        shift
        local findevt=$(setup_tmpf .event)
        htd__jrnl_times list "$@" | while read file date time
        do
          gcalcli search --calendar Journal/Htd-Events "[$time] jrnl" "$date"\
            > $findevt
          grep -q No.Events.Found $findevt && {
            gcalcli add --details url --calendar Journal/Htd-Events \
              --when "$date $time"\
              --title "$(head -n 1 $file )" \
              --duration 10 \
              --where "+htdocs:personal/journal" \
              --description "[$time] jrnl" \
              --reminder 0 &&
                note "New entry $date $time" ||
                error "Entering $date $time for $file"
          } || {
            info "Existing entry $date $time"
          }
        done
      ;;

    * ) error "jrnl-times '$1'?" 1 ;;
  esac
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


htd__port()
{
  case "$uname" in
    Darwin ) lsof -i :$1 || return ;;
    Linux ) netstat -an $1 || return ;;
  esac
}

htd__ps()
{
  upper=0 default_env out-fmt yaml
  default_env pretty 1
  test -n "$1" || set -- $$
  # Cannot parse the headers for fixed-table, other than try sort them out into
  # left and right aligned columns and try to go from there, ie. hardcoding at
  # least half of the set and sniffing the first data row. But even then it
  # still makes it ambigious to parse columns containing whitespace, which
  # ps by default seems to delegate to the last column.
  # So instead, ignore whitespace and make a special case of CMD too, and
  # simply add other values using one subshell each.
  ps -o \
  'sess,sig,sigmask,pri,uid,gid,pid,ppid,cpu,%mem,time,etime,nice,state,tty,command'\
    "$1" | tail -n +2 |
  while read sess sig sigmask pri uid gid pid ppid cpu mempc time etime nice state tty cmd
  do { test "$tty" = "??" && tty= ; cat <<EOM
{"SID": "$sess", "UID": $uid, "GID": $gid, "PID": $pid, "PPID": $ppid, "tty": "$tty", "CPU": $cpu, "MEM": $mempc, "lstart": "$(ps -olstart "$1" | tail -n +2)", "nice": "$nice", "cputime": "$time", "state": "$state", "ELAPSED": "$etime", "CMD": "$cmd", "CWD":"$( lsof -p "$1" | grep cwd | awk '{print $9}')", "priority": $pri, "pending": "$sig", "blocking": "$sigmask"}
EOM
    }
  done | {
    test "$out_fmt" = "yaml" && jsotk json2yaml --pretty - || {
      trueish "$PRETTY" && jsotk dump --pretty - || cat -
    }
  }
}
htd_of__ps='yaml json'


# TODO: open routine ...
htd__open()
{
  test -n "$1" && {
    stderr warn TODO 1 # tasks-ignore
  } || {
    htd__open_paths || return
  }
}


htd_man_1__open_paths='List open paths for user (beloning to shell processes only)'
htd__open_paths()
{
  # BUG: lsof -Fn  on OSX/Darwin ie behaving really badly, looks buggy.
  # So awk for paths
  lsof \
    +c 15 \
    -c '/^(bash|sh|ssh|dash|zsh)$/x' \
    -u $(whoami) -a -d cwd | tail -n +2 | awk '{print $9}' | sort -u
}
htd_of__open_paths='list'


htd_man_1__current_paths='
  List open paths under given or current dir. Dumps lsof without cmd, pid etc.'
htd__current_paths()
{
  test -n "$1" || set -- "$(pwd -P)"
  note "Listing open paths under $1"
  # print only pid and path name, keep name
  lsof -F n +D $1 | tail -n +2 | grep -v '^p' | cut -c2- | sort -u
}
htd_als__lsof=current


htd__x_lsof()
{
  lsof
}


htd_man_1__open_paths_diff='Create list of open files, and show differences on
  subsequent calls. '
htd_spc__open_paths_diff="open-paths-diff"
htd__open_paths_diff()
{
  export lsof=$(statusdir.sh assert-dir htd/open-paths.lsof)
  export lsof_paths=$lsof.paths
  export lsof_paths_ck=$lsof_paths.sha1

  # Get open paths for user, include only CWD, and with 15 COMMAND chars
  # But keep only non-root, and sh or bash lines, throttle update of cached file
  # by 10s period.
  {
    test -e "$lsof" && newer_than $lsof 10
  } || {
    htd__open_paths >$lsof

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


req_prefix_names_index()
{
  test -n "$1" || set -- pathnames.tab
  test -n "$index" || export index=$(setup_tmpf .prefix-names-index)
  test -s "$index" -a "$index" -nt "$UCONF/$1" || {
    htd_topic_names_index "$1" > $index
  }
}

# Run path-prefix-name for all paths from htd-open.
htd__prefixes()
{
  test -n "$index" || local index=
  test -s "$index" || req_prefix_names_index
  test -n "$1" || set -- op
  case "$1" in

    list | names )            htd__prefix_names || return ;;
    all-paths | tree )        htd__list_prefixes || return ;;
    table )                   htd__path_prefix_names || return ;;
    name ) shift ;           htd__prefix_name "$1" || return ;;
    expand ) shift ;         htd__prefix_expand "$1" || return ;;
    check ) shift
        htd__prefix_names | while read name
        do
            mkvid "$name"
            val="$( eval echo \"\$$vid\" )"
            test -n "$val" || warn "No env for $name"
        done
      ;;

    op | open-files | read-lines ) shift
        { test -n "$1" && {
          read_nix_style_file "$1" || return
        } || {
            htd__open || return
        };} | while read path
        do
          htd__prefix_name "$path"
        done
      ;;
  esac
  rm $index
}


# List prefix varnames
htd__prefix_names()
{
  test -n "$index" || local index=
  test -s "$index" || req_prefix_names_index
  read_nix_style_file $index | awk '{print $2}' | uniq
}


# Return prefix:<localpath> after scanning paths-topic-names
htd__prefix_name()
{
  test -n "$index" || local index=
  test -s "$index" || req_prefix_names_index
  fnmatch "/*" "$path" || set -- "$(pwd -P)/$1"
  fnmatch "*/" "$path" || {
    test -e "$1" -a -d "$1" && set -- "$1/"
  }
  local path="$1"
  # Find deepest named prefix
  while true
  do
    # Travel to root, break on match
    grep -qF "$1 " "$index" && break || set -- "$(dirname "$1")/"
    test "$1" != "//" && continue || set -- /
    break
  done
  # Get first name for path
  local prefix_name="$( grep -F "$1 " $index | head -n 1 | awk '{print $2}' )"
  fnmatch "*/" "$1" || set -- "$1/"
  # offset on furter for `cut`
  set -- "$1+"
  local v="$( echo "$path" | cut -c${#1}- )"
  test -n "$v" || {
    test "$prefix_name" == ROOT && v=/
  }
  echo "$prefix_name:$v"
}


htd__prefix_expand()
{
  test -n "$1" || error "Prefix-Path-Arg expected" 1
  {
    test "$1" = "-" && { cat - ; shift ; }
    for a in "$@" ; do echo "$a" ; done
  } | tr ':' ' ' | while read prefix lname
  do
    echo "$(eval echo \"\$$prefix\")/$lname"
  done
}


# Print user or default prefix-name lookup table
htd__path_prefix_names()
{
  test -n "$index" || local index=
  req_prefix_names_index
  test -s "$index"
  cat $index | sed 's/^[^\#]/'$(hostname -s)':&/g'
  note "OK, $(count_lines "$index") rules"
}


htd_of__list_prefixes='plain text txt rst yaml yml json'
htd__list_prefixes()
{
  test -n "$out_fmt" || out_fmt=plain
  test -n "$sd_be" || sd_be=redis
  (
    case "$out_fmt" in json ) printf "[" ;; esac
    case "$sd_be" in
      redis ) statusdir.sh be smembers htd:prefixes:names ;;
      couchdb_sh ) warn todo 1 ;;
      * ) warn "not supported statusdir backend '$sd_be' " 1 ;;
    esac | while read prefix
    do
      test -n "$(echo $prefix)" &&
        local val="$(eval echo \"\$$prefix\")" ||
        local prefix=ROOT val=/
      case "$out_fmt" in
        plain|text|txt )
            test -n "$val" &&
              printf -- "$prefix <$val>\n" || printf -- "$prefix\n"
          ;;
        rst|restructuredtext )
            test -n "$val" &&
              printf -- "\`$prefix <$val>\`_\n" || printf -- "$prefix\n"
          ;;
        yaml|yml )
            test -n "$val" &&
              printf -- "- prefix: $prefix\n  value: $val\n  paths:" ||
              printf -- "- prefix: $prefix\n  paths:"
          ;;
        json ) test -z "$val" &&
            printf "{ \"name\": \"$prefix\", \"subs\": [" ||
            printf "{ \"name\": \"$prefix\", \"path\": \"$val\", \"subs\": ["
          ;;
      esac
      case "$sd_be" in
        redis ) statusdir.sh be smembers htd:prefix:$prefix:paths ;;
        * ) warn "not supported statusdir backend '$sd_be' " 1 ;;
      esac | while read localpath
      do
        test -n "$localpath" || continue
        case "$out_fmt" in
          plain|text|txt|rst )
              test -z "$localpath" &&
                printf -- "  ..\n" ||
                printf -- "  - $localpath\n"
            ;;
          yaml|yml )
              test -z "$localpath" &&
                printf -- " []" ||
                printf -- "\n  - '$localpath'"
            ;;
          json ) printf "\"$localpath\"," ;;
        esac
      done
      case "$out_fmt" in yaml|yml|plain|text|txt|rst ) echo ;;
        json ) printf "]}," ;;
      esac
    done
    case "$out_fmt" in json ) printf "]" ;; esac
  ) | {
    test "$out_fmt" = "json" && sed 's/,\]/\]/g' || cat -
  }
}
htd_als__prefixes_list=list-prefixes


htd__update_prefixes()
{
  (
    sd_be=redis

    htd__prefixes | while IFS=':' read prefix localpath
    do
      test -n "$prefix" -a -n "$localpath" || continue

      statusdir.sh be sadd htd:prefixes:names "$prefix" >/dev/null &&
        stderr ok "Added '$prefix' to prefixes" ||
        error "Adding '$prefix' to prefixes " 1
      statusdir.sh be sadd htd:prefix:$prefix:paths $localpath >/dev/null &&
        stderr ok "Added '$localpath' to prefix '$prefix'" ||
        error "Adding '$localpath' to prefix '$prefix' " 1
      echo $prefix:$localpath

    done
    COUCH_DB=htd sd_be=couchdb_sh \
    statusdir.sh del htd:$hostname:prefixes
    {
      printf -- "_id: 'htd:$hostname:prefixes'\n"
      #printf -- "fields: type: ""'\n"
      printf -- "type: 'application/vnd.wtwta.htd.prefixes'\n"
      printf -- "prefixes:\n"
      out_fmt=yml htd__list_prefixes
    } |
    jsotk yaml2json |
      curl -X POST -sSf $COUCH_URL/$COUCH_DB/ \
        -H "Content-Type: application/json" \
        -d @- && note "Submitted to couchdb" || {
          error "Sumitting to couchdb"
          return 1
        }
      #COUCH_DB=htd sd_be=couchdb_sh \
      #  statusdir.sh set ""
  )
}
htd_als__prefixes_update=update-prefixes


htd_man_1__service_list='
List servtab entries, optionally updating
'
htd_of__service_list='text txt list plain'
htd__service_list()
{
  test -n "$service_cmd" || service_cmd=status
  htd_service_env_req
  fixed_table $HTD_SERVTAB UNID TYPE EXP CTX | while read vars
  do
    eval local "$vars"
    DIR=$(echo "$CTX" | awk '{print $1}')
    HTD_SERV_ENV="${CTX:${#DIR}}"
    DIR=$(eval echo "$DIR")
    cd $DIR || {
      error "service $UNID dir missing: '$DIR'"
      continue
    }
    # XXX: interpret recorded
    trueish "$update" || {
      # XXX: nicely formatted stdout $UNID $TYPE $DIR ...
      test -z "$HTD_SERV_ENV" || eval $HTD_SERV_ENV
      # NOTE: Get a bit nicer name.
      # FIXME: would want package metadata. req. new code getting type specific
      # metadata. Not sure yet where to group it.. services, environment.
      #package_get_key "$DIR" $package_id label name id
      upper=1 mkvid "$TYPE"
      NAME=$(eval echo \$${vid}_NAME)
      echo "$UNID: $NAME @$TYPE $(htd_service_status_info "$TYPE" "$EXP") <$DIR>"
      continue
    }
    # XXX: interpret current results
    test "$service_cmd" = status || {
      htd__service $service_cmd "$UNID" "$TYPE" "$DIR" ||
        warn "'$service_cmd' returned $?" 1
      continue
    }
    # XXX: update
    htd__service $service_cmd "$UNID" "$TYPE" "$DIR" && {
      test -z "$EXP" -o "$EXP" = "0" &&
        stderr OK "OK $TYPE $htd_serv_stat_msg [$DIR] ($UNID) "  ||
        warn "Unexpected state 0 for $TYPE [$DIR] ($UNID)"
    } || { E=$?
      test "$E" = "$EXP" && {
        stderr note "Ingored non-zero state $EXP for $TYPE [$DIR] ($UNID)"
      } ||
        stderr fail "Failed $TYPE err $E $htd_serv_stat_msg [$DIR] ($UNID) "
    }
  done
}
htd_als__list_services=service-list


htd__service() # Cmd [ Sid [ Type [ Dir ]]]
{
  test -n "$1" || set -- list
  test -n "$htd_serv_update" || export htd_serv_update=1
  case "$1" in
    info | record )
        test -z "$3" -a -z "$4"
        test -n "$2" && {
          htd_service_record "$2"
        } || {
          echo
        }
      ;;
    reload ) ;;
    status | install | init | start | stop | restart | deinit | uninstall )
        shift
        CTX=$(htd_service_attr "$1" CTX )
        DIR=$(echo "$CTX" | awk '{print $1}')
        HTD_SERV_ENV="${CTX:${#DIR}}"
        DIR=$(eval echo $DIR)
        test -n "$2" -a -n "$3" || {
          set -- $1 $( htd_service_attr "$1" TYPE ) "$DIR"
        }
        htd_service_exists "$@" || {
          trueish "$htd_serv_update" && {
            htd_service_update_record "$@"
          } ||
            return 1
        }
        htd_service_status "$@" || return
        htd_service_update "$@"
      ;;
    list ) test -z "$2" -a -z "$3" -a -z "$4" ;
        echo "#$(fixed_table_hd "$HTD_SERVTAB")"
        update=0 service_cmd=info htd__service_list
      ;;
    list-info ) test -z "$2" -a -z "$3" -a -z "$4" ;
        update=1 service_cmd=status htd__service_list
      ;;
  esac
}


# Scan for bashims in given file or current dir
htd_spc__bashisms="bashism [DIR]"
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

htd_clean_scm()
{
  vc_getscm "$1" && {
    note "Found SCM in $1"
    ( cd "$1" && 
    vc_clean )
  }
}

htd_clean_unpacked_dir()
{
  test -d "$1" || return

  for archive in $(htd__expand $1.{zip,tar{.gz,.bz2}})
  do
    htd__clean_unpacked "$archive"
  done
}

htd__clean()
{
  test -n "$1" || set -- .
  note "Checking $1.."

  local pwd=$(pwd -P) ppwd=$(pwd) spwd=. scm= scmdir=

  htd_clean_scm "$1"

  for localpath in $1/*
  do
    test -d "$localpath" && {

      htd_clean_unpacked_dir "$localpath"

      #htd__clean "$localpath"
    }
  done
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
        test -e "$1" || error "no file '$1'" 1
        local output="$B/$(htd__prefix_name "$1").xhtml"
        {
          trueish "$keep_build" && test -e "$output" -a "$output" -nt "$1"
        } && note "Existing build is up-to-date <$output>" || {
          vim_swap "$1" || error "swap file exists '$1'" 2
          mkdir -p "$(dirname "$output")"
          #  -E -s \
          # -R -E -s  \
          # FIXME: use colorize for converting ANSI dumps to HTML
          # -c "AnsiEsc" \
          vim \
            -c "syntax on" \
            -c "colorscheme mustang" \
            -c "let g:html_no_progress=1" \
            -c "let g:html_number_lines = 0" \
            -c "let g:html_use_css = 1" \
            -c "let g:use_xhtml = 1" \
            -c "let g:html_use_encoding = 'utf-8'" \
            -c "TOhtml" \
            -c "wqa!" \
            "$1"
          mv "$1.xhtml" "$output"
          note "Written to <$output>"
        }
        trueish "$open" && open "$output" || echo " $output"
        trueish "$keep_build" || rm "$output"
      ;;

  esac
}

vim_swap()
{
  local swp="$(dirname "$1")/.$(basename "$1").swp"
  test ! -e "$swp" || {
    trueish "$remove_swap" && rm $swp || return 1
  }
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


htd_man_1__srv='Manage service container symlinks and dirs.

  find-volumes | volumes
      List fully qualified volume names. Optionally filter given existing volume path.
  -names
      List service-container names
  -instances
      List unique service-containers (FIXME: ignore local..)
  -paths
      List existing volume paths (absolute paths)
  find-container-volumes
      List container paths (absolute paths)
  check
  list
  update

'
htd__srv()
{
  test -n "$1" || set -- list
  case "$1" in

    -cnames ) shift
        echo /srv/* | tr ' ' '\n' | cut -d'/' -f3 | sort -u
      ;;

    -vpaths ) shift
        for p in /srv/volume-[0-9]*-[0-9]*-*-*/
        do
          htd__name_exists "$p" "$1" || continue
          echo "$p$name"
        done
      ;;

    -names ) shift
        htd__srv -instances | sed '
            s/^\(.*\)-[0-9]*-[0-9]*-[a-z]*-[a-z]*$/\1/g
            s/^\(.*\)-local$/\1/g
          ' | sort -u
      ;;

    -instances ) shift
  htd__srv -cnames |
          grep -v '^\(\(.*-local\)\|volume-\([0-9]*-[0-9]*-.*\)\)$'
      ;;

    find-volumes | volumes ) shift
        htd__srv -vpaths "$1" | cut -d'/' -f3 | sort -u
      ;;

    find-container-volumes ) shift
        # Additionally to -paths, go over every service container,
        # not just the roots.
        for p in /srv/*/
        do
          htd__name_exists "$p" "$1" || continue
          echo "$p$name"
        done
      ;;

    check ) shift
        # For all local services, we want symlinks to any matching volume path
        htd__srv -names | while read name
        do
          test -n "$name" || error "name" 1
          #htd__srv find-volumes "$name"
          htd__srv find-container-volumes "$name"
          #htd__srv -paths "$name"

          # TODO: find out which disk volume is on, create name and see if the
          # symlink is there. check target maybe.
        done
      ;;

    list ) shift
        test -n "$1" && {
          htd__srv list-volumes "$1"
          htd__srv find-volumes "$1"
        } || {
          htd__srv_list || return $?
        }
      ;;

    update ) shift
        htd__srv init "$@" || return $?
      ;;

    init ) shift
        # Update disk volume catalog, and reinitialize service links
        disk.sh check-all || {
          disk.sh update-all || {
            error "Failed updating volumes catalog and links"
          }
        }
      ;;

    * ) error "'$1'?" 1 ;;

  esac
}

# check for both 'lower-case' sid and Title Case dir name.
htd__name_exists() # DIR NAME
{
  name="$2"
  test -e "$1/$2" && return
  upper=0 mksid "$2"
  name="$sid"
  test -e "$1/$sid" && return
  upper= mksid "$(str_title "$2")"
  name="$sid"
  test -e "$1/$sid" && return
  return 1
}


# Volumes for services

htd_man_1__srv_list="Print info to stdout, one line per symlink in /srv"
htd_spc__srv_list="out_fmt= srv-list"
htd_of__srv_list='DOT'
htd__srv_list()
{
  upper=0 default_env out-fmt plain
  out_fmt="$(echo $out_fmt | str_upper)"
  test -n "$verbosity" -a $verbosity -gt 5 || verbosity=6
  case "$out_fmt" in
      DOT )  echo "digraph htd__srv_list { rankdir=RL; ";; esac
  for srv in /srv/*
  do
    test -h $srv || continue
    cd /srv/
    target="$(readlink $srv)"
    name="$(basename "$srv" -local)"
    test -e "$target" || {
      stderr warn "Missing path '$target'"
      continue
    }
    depth=$(htd__path_depth "$target")

    case "$out_fmt" in
        DOT )
            NAME=$(mkvid "$name"; echo $vid)
            TRGT=$(mkvid "$target"; echo $vid)
            case "$target" in
              /mnt*|/media*|/Volumes* )

                  echo "$TRGT [ shape=box3d, label=\"$(basename "$target")\" ] ; // 1.1"
                  echo "$NAME [ shape=tab, label=\"$name\" ] ;"

                  DISK="$(cd /srv; disk.sh id $target)"

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
  case "$out_fmt" in
      DOT )  echo "} // digraph htd__srv_list";; esac
}

# services list
SRVS="archive archive-old scm-git src annex www-data cabinet htdocs shared \
  docker"
# TODO: use service names from disk catalog


# Go over local disk to see if volume links are there
htd__ls_volumes()
{
  disk.sh list-local | while read disk
  do
    prefix=$(disk.sh prefix $disk 2>/dev/null)
    test -n "$prefix" || {
      warn "No prefix found for <$disk>"
      continue
    }

    disk_index=$(disk.sh info $disk disk_index 2>/dev/null)

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
htd_als__list_volumes=ls-volumes


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
  req_dir_env HTDIR
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
htd_run__backup=iAOP
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
htd_pre__backup=htd_backup_prereq
htd_argsv__backup=htd_backup_args
htd_optsv__backup=htd_backup_opts


htd_man_1__pack_create="Create archive for dir with ck manifest"
htd_man_1__pack_verify="Verify archive with manifest, see that all files in dir are there"
htd_man_1__pack_check="Check file (w. checksum) TODO: dir with archive manifest"
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


htd__basenames()
{
  test -n "$*" && basenames "$@" || {
    basenames .rst $( lines_to_words )
  }
}


htd_spc__pathnames="exts=DOC-EXTS pathname PATH.."
htd__pathnames()
{
  test -n "$exts" || exts="$DOC_EXTS"
  {
    pathnames "$@" || return $?
  } | sort -u
}



# Shell script source


htd_man_1__src_info=
htd_grp__src_info=box-src
htd__src_info()
{
  test -n "$1" || set -- $0
  for src in $@
  do
    src_id=$(htd__prefix_name $src)
    $LOG file_warn $src_id "Listing info.."
    $LOG header "Box Source"
    $LOG header2 "Functions" $(htd__list_functions "$@" | count_lines)
    $LOG header3 "Lines" $(count_lines "$@")
    $LOG file_ok $srC_id
  done
  $LOG done $subcmd
}


htd_man_1__functions='List functions, group, filter, and use `source` to get
source-code info. '
htd__functions()
{
  test -n "$1" || set -- copy
  case "$1" in

    list-functions|list-func|ls-functions|ls-func ) shift
        htd__list_functions "$@"
      ;;
    list-function-attr ) shift ; htd__list_function_attr "$@" ;;
    list-function-group ) shift ; htd__list_function_group "$@" ;;
    filter-functions ) shift ; htd__filter_functions "$@" ;;
    diff-function-names ) shift ; htd__diff_function_names "$@" ;;
    list-functions-added|new-functions ) shift
        htd__list_functions_added "$@"
      ;;
    list-functions-removed|deleted-functions ) shift
        htd__list_functions_removed "$@"
      ;;

    ranges ) shift
        test -n "$2" && multiple_srcs=1 || multiple_srcs=0
        htd__list_functions "$@" | while read a1 a2 ; do
          test -n "$a1" -o -n "$a2" || continue
          test -n "$a2" && { f=$a2; s=$a1; } || { f=$a1; s=$1; }
          f="$(echo $f | tr -d '()')" ; upper=0 mkvid "$f"
          r="$(eval scrow regex --rx-multiline --fmt range \
            "$s" "'^$vid\\(\\).*((?<!\\n\\})\\n.*)*\\n\\}'")"
          trueish "$multiple_srcs" && echo "$s $f $r" || echo "$f $r"
        done
      ;;

    filter-ranges ) shift
        test -n "$3" && multiple_srcs=1 || multiple_srcs=0
        upper=0 default_env out-fmt xtl
        out_fmt=names htd__filter_functions "$@" | while read a1 a2
        do
          test -n "$a1" -o -n "$a2" || continue
          test -n "$a2" && { f=$a2; s=$a1; } || { f=$a1; s=$2; }
          upper=0 mkvid "htd__$(echo $f | tr -d '()')"
          r="$( eval scrow regex --rx-multiline --fmt $out_fmt \
            "$s" "'^$vid\\(\\).*((?<!\\n\\})\\n.*)*\\n\\}'")"
          test -n "$r" || { warn "No range for $s $f"; continue; }
          case "$out_fmt" in xtl ) echo $r ;;
            * ) trueish "$multiple_srcs" && echo "$s $f $r" || echo "$f $r" ;;
          esac
        done
      ;;

    * ) error "'$1'?" 1 ;;
  esac
}


htd_man_1__list_functions='
List all function declaration lines found in given source, or current executing
script.
'
htd_spc__list_functions='(ls-func|list-func(tions)) [ --(no-)list-functions-scriptname ]'
htd_run__list_functions=iAO
htd_grp__list_functions=box-src
htd__list_functions()
{
  test -z "$2" || {
    # Turn on scriptname output prefix if more than one file is given
    var_isset list_functions_scriptname || list_functions_scriptname=1
  }
  list_functions "$@"
}
htd_als__list_func=list-functions
htd_als__ls_functions=list-functions
htd_als__ls_func=list-functions


# Note: initial try at parsing out attr
htd_man_1__list_function_attr='List all box functions with their attribute
key-names. By default set FILE to executing script (ie. htd). '
htd_spc__list_function_attr='list-function-attr [FILE]'
htd__list_function_attr()
{
  test -n "$1" || set -- $0
  for f in $@
  do
    grep '^[a-z][0-9a-z_]*__[0-9a-z_]*().*$' $f | sed 's/().*$//g' |
      grep -v 'optsv' | grep -v 'argsv' | sort -u |
      while read subcmd_func
    do
      base=$(echo $subcmd_func | sed 's/__.*$//g')
      function=$(echo $subcmd_func | sed 's/^.*__//g')
      printf -- "  $(echo $function | tr '_' '-')\n"
      eval grep "'^${base}_.*__${function}\\(\\(=.*\\)\\|()\\)$'" $f |
        sed -E 's/(=|\().*$//g' | while read attr_field
      do
        printf -- "   - $(echo $attr_field |
          cut -c1-$(( ${#attr_field} - ${#field} - 2 )) |
          cut -c$(( ${#base} + 2 ))- |
          tr '_' '-')\n"
      done
    done
  done
}
htd_grp__list_function_attr=box-src


htd_man_1__list_function_groups='List distinct values for "grp" attribute. '
htd_spc__list_function_groups='list-function-groups [ Src-Files... ]'
htd__list_function_groups()
{
  test -n "$1" || set -- "$0"
  for src in "$@"
  do
    grep '^[a-z][0-9a-z_]*_grp__[a-z][0-9a-z_]*=.*' $src | sed 's/^.*=//g'
  done | uniq
}


htd_man_1__filter_functions='
  Find and list all function and attribute declarations from Src-Files,
  filtering by one or more key=regex inclusively or exclusively. Output is
  normally a list of function names (out_fmt=names), or else all declaration
  lines (out_fmt=src).

  In inclusive mode one big grep-for is build from the filters and execution is
  done on each src with the accumulated result rewritten to unique function
  names, if requested (out-fmt=names).

  For exclusive mode, a grep for each filter is executed seperately against each
  source. With filter the resulting function-keys set is narrowed down, with
  then the resulting function keys being listed as is (out-fmt=names) or grepped
  from the source (out-fmt=src).

  Depending on the output format requested, more processing is done. The
  simplest format is names, followed by src. All other formats list beside the
  script-name, also the attributes values. However as some attributes may be
  multiline, they require additional source lookup to output.

  Other supported formats besides names and src are csv, json and yaml/yml.
  Each of these sources the source script and dereferences the required
  attribute values. '

htd_spc__filter_functions='filter-functions Attr-Filter [Src-Files...]'
htd__filter_functions() # Attr-Filter [Src-Files...]
{
  upper=0 default_env out-fmt names
  title=1 default_env Inclusive-Filter 1
  # With no filter env, use first argument or set default
  test -n "$Attr_Filter" || {
    test -n "$1" || { shift; set -- grp=box-src "$@"; }
    Attr_Filter="$1"
  }
  shift # first arg is ignored unless Attr_Filter is empty
  debug "Filtering functions from '$*' ($(var2tags Attr_Filter Inclusive_Filter ))"
  # sort out the keys from the filter into Filters, and export filter_$key env
  Filters=
  for kv in $Attr_Filter ; do
    k=$(get_kv_k "$kv") ; v=$(get_kv_v "$kv" filter_ $k)
    export filter_$k="$v" Filters="$Filters $k"
  done
  # Assemble grep args (inclusive mode) or grep-pattern lines (exclusive mode)
  Grep_For="$(
      for filter in $Filters ; do test -n "$filter" || continue
        trueish "$Inclusive_Filter" && printf -- "-e "
        printf -- "'^[a-z_]*_${filter}__.*=$(eval echo \"\$filter_${filter}\")' "
      done
    )"
  # Output function names to file, adding all declaration lines (inclusive mode)
  # or filtering out non-matching function-names (exclusive mode)
  local outf=$(setup_tmpf .out-$out_fmt-tmp)
  for src in "$@"
  do
    test -n "$src" || continue
    local func_keys=$(setup_tmpf .func-keys)
    {
      trueish "$Inclusive_Filter" && {
        eval grep $Grep_For $src |

          case "$out_fmt" in names )
              sed 's/^[a-z][a-z0-9_]*__\([^=(]*\).*$/\1/' ;;
          * )
              sed 's/^[a-z][a-z0-9_]*__\([^=(]*\).*$/\1/' > $func_keys
              eval grep "$( while read func_key ; do
                  printf -- "-e '^[a-z_]*__$func_key[=(].*' " ; done < $func_keys
                )" "$@"
            ;;
          esac
      } || {
        local src_lines=$(setup_tmpf .src-lines)
        grep  '^[a-z][a-z0-9_]*__.*[=(].*' "$src" > $src_lines
        for Grep_Rx in $Grep_For
        do
          mv $src_lines $src_lines.tmp
          eval grep $Grep_Rx $src | sed 's/^[a-z][a-z0-9_]*__\([^=(]*\).*$/\1/' > $func_keys
          test -s "$func_keys" || {
            warn "No matches for $Grep_Rx '$src'"
            return 1
          }
          # Remove functions declarations from src-lines where no matching func-keys
          eval grep "$( while read func_key ; do
              printf -- "-e '^[a-z][a-z0-9_]*__$func_key[=(].*' " ; done < $func_keys
            )" $src_lines.tmp > $src_lines
          rm $src_lines.tmp
        done

        case "$out_fmt" in
          names ) sed 's/^[a-z][a-z0-9_]*__\([^=(]*\).*$/\1/' $src_lines ;;
          * ) test -s "$src_lines" &&
              cat $src_lines || warn "Nothing found for '$src'"
            ;;
        esac
      }
    } | sed 's#^.*#'$src' &#'
  done > $outf
  test -s "$outf" && {
    cat $outf | htd_filter_functions_output
  } || {
    rm $outf
    return 1
  }
  rm $outf
}
htd_grp__filter_functions=box-src
htd_filter_functions_output()
{

  case "$out_fmt" in
    names ) tr '_' '-'  | uniq ;;
    src ) cat - ;;
    * ) cat - |
        sed 's/\([^\ ]*\)\ \([a-z][a-z0-9_]*\)__\([^(]*\)().*/\1 \3/g' |
        sed 's/\([^\ ]*\)\ \([a-z][a-z0-9_]*\)__\([^=]*\)=\(.*\)/\1 \3 \2 \4/g' |
        while read script_name func_name func_attr func_attr_value
        do # XXX: I whish I could replace this loop with a sed/awk/perl oneliner
          test -n "$func_attr_value" || {
            echo "$script_name $func_name" ; continue
          }
          echo "$script_name $func_name $(
              dsp=$(( ${#script_name} + 2 ))
              expr_substr "$func_attr" $dsp  $(( 1 + ${#func_attr} - $dsp ))
            ) $func_attr_value"
        done | sort -u | {
          case "$out_fmt" in
            csv )      htd_filter_functions_output_csv || return $? ;;
            yaml|yml ) htd_filter_functions_output_yaml || return $? ;;
            json )     htd_filter_functions_output_yaml | jsotk yaml2json - ||
              return $? ;;
          esac
        }
      ;;
  esac
}
htd_filter_functions_output_csv()
{
  local current_script=
  echo "# Script-Name, Func-Key, Func-Attr-Key, Func-Attr-Value"
  while read script_name func_key func_attr_key func_attr_value
  do
    test -n "$func_attr_value" || {
      test "$script_name" = "$current_script" || {
        export __load_lib=1
        source $script_name
        current_script=$script_name
      }
      continue
    }
    upper=0 mkvid "$script_name"
    value="$( eval echo \"\$${vid}_${func_attr_key}__${func_key}\" )"
    fnmatch "*\n*\n*" "$value" &&
      value="$( echo "$value" | sed 's/$/\\n/g' | tr -d '\n' )"
    echo "$script_name,$func_key,$func_attr_key,\"$value\""
  done
}
htd_filter_functions_output_yaml()
{
  local current_script=
  while read script_name func_key func_attr_key func_attr_value
  do
    test "$script_name" = "$current_script" || {
      export __load_lib=1
      source $script_name
      echo "type: application/vnd.org.wtwta.box-instance"
      echo "script-name: $script_name"
      echo "command-functions:"
      current_script=$script_name
    }
    test -n "$func_attr_value" || {
      echo "  - subcmd: $(echo $func_key | tr '_' '-')"
      continue
    }
    upper=0 mkvid "$script_name"
    value="$( eval echo \"\$${vid}_${func_attr_key}__${func_key}\" )"
    fnmatch "*\n*\n*" "$value" && {
      value="$(echo "$value" | jsotk encode -)"
      # FIXME: htd filter-functions out-fmt=yaml could use pretty multilines
      echo "    $(echo $func_attr_key | tr '_' '-'): $value"
    } || {
      echo   "    $(echo $func_attr_key | tr '_' '-'): '$value'"
    }
  done
}


htd_grp__list_functions_added=box-src
htd__list_functions_added()
{
  filter=A htd__diff_function_names "$@"
}
htd_als__new_functions=list-functions-added


htd_grp__list_functions_removed=box-src
htd__list_functions_removed()
{
  filter=D htd__diff_function_names "$@"
}
htd_als__deleted_functions=list-functions-removed


htd_man_1__diff_function_names='
  Compare function names in script, show changes
'
htd_grp__diff_function_names=box-src
htd__diff_function_names()
{
  local version2=$2 version1=$1
  shift 2
  test -n "$1" || set -- "$(echo $scriptpath/*.sh)"
  test -n "$filter" || filter=A
  tmplistcur=$(setup_tmpf .func-list)
  tmplistprev=$(setup_tmpf .func-list-old)
  test -n "$version2" || version2=HEAD^
  {
    cd $scriptpath
    for name in $@
    do
      fnmatch "/*" "$name" &&
        name=$(echo "$name" | cut -c$(( 2 + ${#scriptpath} ))-)
      git show $version2:$name | list_functions - |
        sed 's/\(\w*\)()/\1/' | sort -u > $tmplistprev
      test -n "$version1" && {
        note "Listing new fuctions at $version1 since $version2 in $name"
        git show $version1:$name | list_functions - |
          sed 's/\(\w*\)()/\1/' | sort -u > $tmplistcur
      } || {
        note "Lising new fuctions since $version2 in $name"
        list_functions $name | sed 's/\(\w*\)()/\1/' | sort -u > $tmplistcur
      }
      case "$filter" in
        U ) comm_f=" -1 -2 " ;;
        A ) comm_f=" -2 -3 " ;;
        D ) comm_f=" -1 -3 " ;;
        * ) comm_f=" " ;;
      esac
      comm $comm_f $tmplistcur $tmplistprev
    done
  }
}



htd__vcard2n3()
{
  swap_dir=/home/berend/project/w3c-swap/swap.mpe/
  PYTHONPATH=$swap_dir:$PYTHONPATH $swap_dir/pim/vcard2n3.py $*
}


# this acts as a remote diff program, accepting two files and displaying
# a diff for them.  Zero, one, or both files can be remote.  File paths
# must be in a format `scp` understands: [[user@]host:]file
htd__rsdiff()
{
  f1=/tmp/rdiff.1
  f2=/tmp/rdiff.2
  scp $1 $f1
  scp $2 $f2
  if [ -f $f1 -a -f $f2 ]; then
    vimdiff -b $f1 $f2
  fi
  rm -f $f1 $f2
}


htd__crypto_volumes()
{
  for x in /srv/volume-[0-9]*
  do
    test -d $x/crypto || continue
    echo $x/crypto
  done
}

htd__crypto_volume_find()
{
  test -n "$*" || return
  while test $# -gt 0
  do
    htd__crypto_volumes | while read volume
    do
      echo "$volume/$1"
      test -e "$volume/$1" || continue
      echo "$volume/$1"
    done
    shift
  done
}

htd_man_1__crypto='
  list         Show local volumes with crypto folder
  find         Find local crypto volume with specific volume Id.
  find-all     Show all volume Ids found on local volume paths.
  check        See if htd crypto is good to go
'
htd__crypto()
{
  test -n "$1" || set -- check
  # TODO: use crypto source or something
  cr_m=$HTDIR/crypto/main.tab
  test -e $cr_m || cr_m=~/.local/etc/crypto-bootstrap.tab
  case "$1" in

    list ) htd__crypto_volumes || return ;;
    find ) htd__crypto_volume_find "$@" || return ;;
    list-ids|find-all ) echo "#Volume-Id,File-Size"; htd__crypto_volumes | while read v
      do for p in $v/*.vc ; do echo "$(basename $p .vc) $(filesize "$p")" ; done
      done ;;

    check )
      test -x "$(which veracrypt)" || error "VeraCrypt exec missing" 1
      test -e $cr_m || error cr-m-tab 1
      veracrypt --version || return ;;
    
    mount-all ) htd__crypto_mount_all || return ;;
    mount ) htd__crypto_mount "$@" || return ;;
    unmount ) htd__crypto_unmount "$@" || return ;;

    * ) error "'$1'? 'htd crypto $*'" 1 ;;
  esac
}

htd__crypto_mount_all()
{
  test -e $cr_m || error cr-m-tab 1
  c_tab() { fixed_table $cr_m Lvl VolumeId Prefix Contexts ; }
  c_tab | while read vars
  do eval $vars
    test -n "$Prefix" || continue
    test -e "$Prefix" || {
      test -d "$(dirname "$Prefix")" || {
        warn "Missing path '$Prefix'"; continue;
      }
      mkdir -p "$Prefix"
    }
    test -d "$Prefix" || { warn "Non-dir '$Prefix'"; continue; }
    Prefix_Real=$(cd "$(dirname "$Prefix")"; pwd -P)/$(basename "$Prefix")
    mountpoint -q "$Prefix_Real" && {
      note "Already mounted: $Lvl: $VolumeId ($Contexts at $Prefix)"
    } || {
      htd__crypto_mount "$Lvl" "$VolumeId" "$Prefix_Real" "$Contexts" && {
        stderr ok "$Lvl: $VolumeId ($Contexts at $Prefix)"
      } || {
        warn "Mount failed"
        continue
      }
    }
    mountpoint -q "$Prefix_Real" || {
      warn "Non-mount '$Prefix'"; continue;
    }
  done
}
htd_run__crypto=f

htd__crypto_mount() # Lvl VolumeId Prefix_Real Contexts
{
  local device=$(htd__crypto_volume_find "$2.vc")
  test -n "$device" || {
    error "No volume found for '$2'"
    return 1
  }
  . ~/.local/etc/crypto.sh
  test -n "$(eval echo \$$2)" || {
    error "No key for $1"
    return 1
  }
  eval echo "\$$2" | \
    sudo veracrypt --non-interactive --stdin -v $device $3
}

htd__crypto_unmount() # VolumeId
{
  local device=$(htd__crypto_volume_find "$1.vc")
  test -n "$device" || error "Cannot find mount of '$1'" 1
  note "Unmounting volume '$1' ($device)"
  sudo veracrypt -d $device
}

htd__crypto_vc_init() # VolumeId Secret Size
{
  test -n "$1" || set -- Untitled0002 "$2"
  test -n "$2" || error passwd-var-expected 1
  test -n "$3" || set -- "$1" "$2" "10M"
  eval echo "\$$2" | \
    sudo veracrypt --non-interactive --stdin \
      --create $1.vc --hash sha512 --encryption aes \
      --filesystem exFat --size $3 --volume-type=normal
  mkdir /tmp/$(basename $1)
  sudo chown $(whoami):$(whoami) $1.vc
  eval echo "\$$2" | \
    sudo veracrypt --non-interactive --stdin \
      -v $1.vc /tmp/$(basename "$1")
}


htd__darwin_profile()
{
  local grep="$1"
  system_profiler -listDataTypes | while read dtype
  do
    test -n "$grep" &&  {
      system_profiler $dtype | eval grep "$grep" &&
        echo "$dtype for $grep" ||
        noop
    } || {
      system_profiler $dtype
    }
  done
}



htd__exif()
{
  exiftool -DateTimeOriginal \
      -ImageDescription -ImageSize \
      -Rating -RatingPercent \
      -ImageID -ImageUniqueID -ImageIDNumber \
      -Copyright -CopyrightStatus \
      -Make -Model -MakeAndModel -Software -DateTime \
      -UserComment  \
    "$@"
}


# Advanced init-symlinks script with multiple modes and attributes
htd_spc__checkout='checkout ID-or-TABLE'
htd_env__checkout='
  symlinks_id=script-mpe-symlinks
  symlinks_attrs= symlinks_file=
'
htd__checkout()
{
  #set -- $(cat $arguments)
  test -e "$1" && fn="$1" || fn="$symlinks_file"
  test -x "$fn" && table_f=- || table_f="$fn"

  info "2.2. Env: $(var2tags id symlinks_fn table_f )"
  test "$table_f" = "-" && {
    # TODO: either generate table
    #alternatively generate table dynamically?
    exit 44 #. $fn
  } || {
    test -e "$table_f" || error "No such table '$table_f'" 1
    fixed_table $table_f $symlinks_attrs | while read vars
    do
      eval "$vars"
      test -e "$DEST" && {
        test "$(readlink $SRC)" = "$DEST" && {
          stderr ok "OK: $DEST"
          continue
        }
        test -h "$DEST" && rm $DEST
      }
      test -e "$DEST" && {
        error "Path exists '$DEST'"
        continue
      }
      ln -s $SRC $DEST
    done
  }
}
htd_run__checkout=ieOAp
htd_argsv__checkout()
{
  (
    package_id=$symlinks_id
    package_file && update_package
  )
  package_id=$symlinks_id package_lib_load
  eval $(map=package_:symlinks_ package_sh id file attrs)
  test -n "$symlinks_attrs" || symlinks_attrs="SRC DEST"
  info "2.1. Env: $(var2tags package_id symlinks_id symlinks_attrs)"
}


htd_man_1__date_shift='Adjust mtime forward or back by number of hours, or other
unit if specified'
htd__date_shift()
{
  test -e "$1" || error "date-shift $1"
  case "$uname" in
    Linux )
        test -n "$2" || set -- "$1" '-1 day'
        touch -r "$1" -d $2 "$1"
      ;;
    Darwin )
        test -n "$2" || set -- "$1" '-1day'
        # '013007' 1hr30m07sec fwd
        #touch --time=mtime -r "$1" -A $2 "$1"
        touch -r "$1" -A $2 "$1"
      ;;
  esac
}
htd_als__rshift=date-shift



htd_man__couchdb='Stuff couchdb
  couchdb htd-scripts
  couchdb htd-tiddlers
'
htd__couchdb()
{
  # XXX: experiment parsing Sh. Need to address bugs and refactor lots
  #cd ~/bin && htd__couchdb_htd_scripts || return $?
  cd ~/hdocs && htd__couchdb_htd_tiddlers || return $?
}


htd__couchdb_htd_tiddlers()
{
  COUCH_DB=tw
  mkdir -vp $HTD_BUILDDIR/tiddlers
  find . \
    -not -ipath '*static*' \
    -not -ipath '*build*' \
    -not -ipath '*node_modules*' \
    -type f -iname '*.rst' | while read rst_doc
  do
    tiddler_id="$( echo $rst_doc | cut -c3-$(( ${#rst_doc} - 4 )) )"


    # Note: does not have the titles format=mediawiki mt=text/vnd.tiddlywiki
    format=html mt=text/html

    tiddler_file=$HTD_BUILDDIR/tiddlers/${tiddler_id}.$format
    mkdir -vp $(dirname $tiddler_file)
    pandoc -t $format "$rst_doc" > $tiddler_file

    wc -l $tiddler_file

    git ls-files --error-unmatch "$rst_doc" >/dev/null && {
      ctime=$(git log --diff-filter=A --format='%ct' -- $rst_doc)
      created=$(date \
        -r $ctime \
        +"%Y%m%d%H%M%S000")
      mtime=$(git log --diff-filter=M --format='%ct' -- $rst_doc | head -n 1)
      test -n "$mtime" && {
        modified=$(date \
          -r $mtime \
          +"%Y%m%d%H%M%S000")
      } || modified=$created
    } || {
      #htd_doc_ctime "$rst_doc"
      #htd_doc_mtime "$rst_doc"
      modified=$(date \
        -r $(filemtime "$rst_doc") \
        +"%Y%m%d%H%M%S000")
      created="$modified"
    }

    tiddler_jsonfile=$HTD_BUILDDIR/tiddlers/${tiddler_id}.json
    { cat <<EOM
    { "_id": "$tiddler_id", "fields":{
        "created": "$created",
        "modified": "$modified",
        "title": "$tiddler_id",
        "text": $(jsotk encode $tiddler_file),
        "tags": [],
        "type": "$mt"
    } }
EOM
    } > $tiddler_jsonfile

    curl -X POST -sSf $COUCH_URL/$COUCH_DB/ \
       -H "Content-Type: application/json" \
      -d @$tiddler_jsonfile

  done
}

# enter function listings and settings into JSON blobs per src
htd__couchdb_htd_scripts()
{
  local src= grp=
  test -n "$*" || set -- htd
  # *.lib.sh
  upper=0 default_env out-fmt names
  groups="$( htd__list_function_groups "$@" | lines_to_words )"
  export verbosity=4 DEBUG=
  for src in "$@"
  do
    for grp in $groups
    do
      Inclusive_Filter=0 \
      Attr_Filter= \
        htd__filter_functions "grp=$grp" $src || {
          warn "Error getting 'grp=$grp' for <$src>"
          return 1
        }
    done
  done
}

#f0720d16cd6bb61319a08aafbf97a1352537ac61

#02/92/80b80c532636930b43ecd92dafaa04fd7bd1644ff7b077ac4959f7883a98
#029280b80c532636930b43ecd92dafaa04fd7bd1644ff7b077ac4959f7883a98

htd__lfs_files()
{
  test -e .gitattributes || return
  x=$HOME/project/docker-git-lfs-test-server/lfs-test-server-darwin-amd64/lfs-content
  grep filter=lfs .gitattributes |
  while read glob f d m s
  do
    for p in $glob
    do
      h=$(shasum -a 256 $p | awk '{print $1}')
      r="$( echo $h | cut -c1-2 )/$( echo $h | cut -c3-4 )/$( echo $h | cut -c5- )"

      echo $p $r
    done
  done
}


htd__env_local()
{
  { env && local; } | sed 's/=.*$//' | grep -v '^_$' | sort -u
}

htd__env()
{
  env | sed 's/=.*$//' | grep -v '^_$' | sort -u
}


htd__vim_get_runtime()
{
  vim -e -T dumb --cmd 'exe "set t_cm=\<C-M>"|echo $VIMRUNTIME|quit' | tr -d '\015'
}


htd_man_1__ips='
    --block-ips
    --unblock-ips
    -grep-auth-log
    --init-blacklist
    --deinit-blacklist
    --blacklist-ips
    -list
    -table
    --blacklist-ssh-password
      Use iptables to block IPs with password SSH login attempts.
'
htd__ips()
{
  fnmatch *" root "* " $(groups) " || sudo="sudo "
  case "$1" in

      deinit-wlist ) shift
          for ip in 185.27.175.61 anywhere
          do
            ${sudo}iptables -D INPUT -s ${ip} -j ACCEPT
          done
        ;;

      init-wlist ) shift
          set -e

          ${sudo}iptables -P FORWARD DROP # we aren't a router
          ${sudo}iptables -A INPUT -m state --state INVALID -j DROP
          ${sudo}iptables -A INPUT -m state --state RELATED,ESTABLISHED -j ACCEPT
          ${sudo}iptables -A INPUT -i lo -j ACCEPT
          # Allow some private nets
          ${sudo}iptables -A INPUT -s 10.0.0.0/8      -j ACCEPT
          # NOTE: the local net
          ${sudo}iptables -A INPUT -s 172.16.0.0/12   -j ACCEPT
          ${sudo}iptables -A INPUT -s 192.168.0.0/16  -j ACCEPT
          #${sudo}iptables -A INPUT -s ${ip} -j ACCEPT

          wlist=$HOME/allowed-ips.list
          wc -l $wlist
          read_nix_style_file $wlist |
          while read ip
          do
            ${sudo}iptables -A INPUT -s ${ip} -j ACCEPT
          done

          ${sudo}iptables -P INPUT DROP # Drop everything we don't accept
        ;;

      init-blist ) shift
          blist=banned-ips.list
          wc -l $blist
          {
            cat $blist
            htd ips -grep-auth-log
          } | sort -u >$blist
          wc -l $blist
          htd ips --init-blacklist
          read_nix_style_file $blist |
          while read ip
          do
            ${sudo}ipset add blacklist $ip
          done
        ;;

      --block-ips ) shift
          for ip in "$@" ; do
              ${sudo}iptables -I INPUT -s $ip -j DROP ; done
        ;;

      --unblock-ips ) shift
          for ip in "$@" ; do
              ${sudo}iptables -D INPUT -s $ip -j DROP ; done
        ;;

      -grep-auth-log ) # get IP's to block from auth.log
          ${sudo}grep \
              ':\ Failed\ password\ for [a-z0-9]*\ from [0-9\.]*\ port\ ' \
              /var/log/auth.log |
            sed 's/.*from\ \([0-9\.]*\)\ .*/\1/g' |
            sort -u
        ;;


      --init-blacklist )
          test -x "$(which ipset)" || error ipset 1
          ${sudo}ipset create blacklist hash:ip hashsize 4096

          # Set up iptables rules. Match with blacklist and drop traffic
          #${sudo}iptables -A INPUT -m set --match-set blacklist src -j DROP
          ${sudo}iptables -A INPUT -m set --match-set blacklist src -j DROP ||
              warn "Failed setting blacklist for INPUT src"
          ${sudo}iptables -A FORWARD -m set --match-set blacklist src -j DROP ||
              warn "Failed setting blacklist for FORWARD src"
          #${sudo}iptables -I INPUT -m set --match-set IPBlock src,dst -j Drop
        ;;

      --deinit-blacklist )
          test -x "$(which ipset)" || error ipset 1
          ${sudo}ipset destroy blacklist
        ;;

      --blacklist-ips ) shift
          for ip in "$@" ; do ${sudo}ipset add blacklist $ip; done
        ;;

      -list ) shift ; test -n "$1" || set -- blacklist
          ${sudo}ipset list $blacklist | tail -n +8
        ;;

      -table ) ${sudo}iptables -L
        ;;

      --blacklist )
          htd__ips -grep-auth-log | while read ip;
          do
            ${sudo}ipset add blacklist $ip
          done
        ;;


      * ) error "? 'ips $*'" 1
        ;;
  esac
}


# util

htd_rst_doc_create_update()
{
  test -n "$1" || error htd-rst-doc-create-update 12
  local outf=$1 title=$2 ; shift 2
  test -s "$outf" && {
    updated=":\1pdated: $(date +%Y-%m-%d)"
    grep -qi '^\:[Uu]pdated\:.*$' $outf && {
      sed -i.bak 's/^\:\([Uu]\)pdated\:.*$/'"$updated"'/g' $outf
    } || {
      warn "Cannot update 'updated' field."
    }
  } || {
    test -n "$title" || set -- "$outf" "$(basename "$(dirname "$(realpath "$outf")")")"
    echo "$title" > $outf
    echo "$title" | tr -C '\n' '=' >> $outf
    while test -n "$1"
    do case "$1" in
      created )  echo ":created: $(date +%Y-%m-%d)" >> $outf ;;
      updated )  echo ":updated: $(date +%Y-%m-%d)" >> $outf ;;
      week )     echo ":period: " >> $outf ;;
      default-rst )
          test -e .default.rst && {
            fnmatch "/*" "$outf" &&
              # FIXME: get common basepath and build rel if abs given
              includedir="$(pwd -P)" ||
                includedir="$(dirname $outf | sed 's/[^/]*/../g')"
            {
              echo ; echo ; echo ".. include:: $includedir/.default.rst"
            } >> $outf
          }
        ;;
    esac; shift; done
    echo  >> $outf
    export cksum="$(md5sum $outf | cut -f 1 -d ' ')"
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
    package_id= \
    subcmd= failed= cmd_als=

  htd_init || exit $?

  case "$base" in

    $scriptname )
        test -n "$1" || {
          test "$stdio_0_type" = "t" && {
            set -- main-doc-edit
          } || {
            set -- status
          }
        }

        #htd_lib || exit $?
        #run_subcmd "$@" || exit $?

        main_init
        export stdio_0_type stdio_1_type stdio_2_type

        htd_lib "$@" || error htd-lib $?

        try_subcmd "$@" && {
          shift 1
          #record_env_keys htd-subcmd htd-env
          box_lib htd || error "box-src-lib $scriptname" 1

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
}

htd_optsv()
{
  set -- $(lines_to_words $options)
  while test -n "$1"
  do
    case "$1" in
      -S* ) search="$(echo "$1" | cut -c3-)" ;;
      * ) define_all=1 main_options_v "$1" ;;
    esac
    shift
  done

  test -n "$choice_interactive" || {
    # By default look at TERM
    test -z "$TERM" || {
      # may want to look at stdio t(ty) vs. f(ile) and p(ipe)
      # here we trigger by non-tty stderr
      test "$stdio_2_type" = "t" &&
        choice_interactive=1 || choice_interactive=0
      export choice_interactive
    }
  }
}

# FIXME: Pre-bootstrap init
htd_init()
{

  # XXX test -n "$SCRIPTPATH" , does $0 in init.sh alway work?
  test -n "$scriptpath"
  local __load_lib=1
  export SCRIPTPATH=$scriptpath
  . $scriptpath/util.sh load-ext || return $?
  lib_load
  . $scriptpath/box.init.sh
  box_run_sh_test
  #export PACKMETA="$(echo $1/package.y*ml | cut -f1 -d' ')"
  lib_load htd meta list
  lib_load box date doc table disk remote ignores package service
  . $scriptpath/vagrant-sh.sh load-ext
  disk_run
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

# Id: script-mpe/0.0.4-dev htd.sh
