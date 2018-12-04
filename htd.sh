#!/bin/bash
#FIXME: !/bin/sh
# Created: 2014-12-17
#
# Htdocs: work in progress 'daily' shell scripts
#
# shellcheck disable # save takes to long...
# shellcheck disable=SC2004 # $/${} is unnecessary on arithmetic variables
# shellcheck disable=SC2005 # Useless echo? NOTE: not, unquoted echoes to normalize whitespace!
# shellcheck disable=SC2015 # A && B || C is not if-then-else
# shellcheck disable=SC2029 # Note that, unescaped, this expands on the client side
# shellcheck disable=SC2034 # unused, unexported var
# shellcheck disable=SC2039 # In POSIX sh, 'local' is undefined
# SC2046 # Quote this to prevent word splitting
# SC2059 # Don't use variables in the printf format string. Use printf "..%s.." "$foo"
# SC2068 # Double quote array expansions to avoid re-splitting elements
# shellcheck disable=SC2086 # double-quote to prevent globbing and word splitting
# SC2119 # Use "$@" if function's $1 should mean script's $1
# shellcheck disable=SC2120 # func references arguments, but none are ever passed
# shellcheck disable=SC2154 # undefined var
# shellcheck disable=SC2155 # declare separately to avoid return masking
# shellcheck disable=SC2209 # Use var=$(command) to assign output (or quote to assign string)
# shellcheck disable=SC2230 # which is non-standard
htd_src=$_

set -o posix
set -e

version=0.0.4-dev # script-mpe


# Generic load/unload for subcmd

htd__inputs="arguments prefixes options"
htd__outputs="passed skipped error failed"

htd_load()
{
  # -- htd box load insert sentinel --

  # Default-Env upper-case: shell env constants
  local upper=1 title=

  export CWD=$(pwd)
  not_trueish "$DEBUG" || {
    test "$CWD" = "$(pwd -P)" || warn "Current path seems to be aliased ($CWD)"
  }

  default_env EDITOR vim || debug "Using EDITOR '$EDITOR'"
  default_env UCONFDIR "$HOME/.conf/" || debug "Using UCONFDIR '$UCONFDIR'"
  default_env TMPDIR "/tmp/" || debug "Using TMPDIR '$TMPDIR'"
  default_env HTDIR "$HOME/public_html" || debug "Using HTDIR '$HTDIR'"
  test -n "$FIRSTTAB" || export FIRSTTAB=50
  test -n "$LOG" -a -x "$LOG" || export LOG=$scriptpath/log.sh
  default_env Script-Etc "$( htd_init_etc|head -n 1 )" ||
    debug "Using Script-Etc '$SCRIPT_ETC'"
  default_env Htd-ToolsFile "$CWD/tools.yml"
  #test -n "$HTD_TOOLSFILE" || HTD_TOOLSFILE="$CWD"/tools.yml
  default_env Htd-ToolsDir "$HOME/.htd-tools"
  # test -n "$HTD_TOOLSDIR" || export HTD_TOOLSDIR=$HOME/.htd-tools
  default_env Jrnl-Dir "personal/journal" || debug "Using Jrnl-Dir '$JRNL_DIR'"
  default_env Htd-GIT-Remote "$HTD_GIT_REMOTE" ||
    debug "Using Htd-GIT-Remote name '$HTD_GIT_REMOTE'"
  default_env Htd-Ext ~/htdocs:~/bin ||
    debug "Using Htd-Ext dirs '$HTD_EXT'"
  default_env Htd-ServTab $UCONFDIR/htd-services.tab ||
    debug "Using Htd-ServTab table file '$HTD_SERVTAB'"
  debug "Using Cabinet-Dir '$CABINET_DIR'"
  test -d "$HTD_TOOLSDIR/bin" || mkdir -p "$HTD_TOOLSDIR/bin"
  test -d "$HTD_TOOLSDIR/cellar" || mkdir -p "$HTD_TOOLSDIR/cellar"
  default_env Htd-BuildDir .build
  test -n "$HTD_BUILDDIR" || exit 121
  #test -d "$HTD_BUILDDIR" || mkdir -p $HTD_BUILDDIR
  export B=$HTD_BUILDDIR

  #default_env Couch-URL "http://localhost:5984"
  default_env GitVer-Attr ".version-attributes"

  # TODO: move env vars to lowercase? or ucfirst case?
  upper=0 title=

  test -n "$stdio_0_type" -a  -n "$stdio_1_type" -a -n "$stdio_2_type" ||
      error "stdio lib should be initialized" 1

  # Check stdin/out are t(ty), unless f(file) or p(ipe) set interactive mode
  test "$stdio_0_type" = "t" -a "$stdio_1_type" = "t" &&
        interactive_io=1 || interactive_io=0
  default_env Choice-Interactive $interactive_io

  # Assume a file or pipe on stdin means batch-mode and data-on-input available
  test "$stdio_0_type" = "t" && has_input=0 || has_input=1
  default_env Batch-Mode $has_input

  # Get project dir and version-control system name
  vc_getscm
  go_to_dir_with ".$scm" && {
    # $localpath is the path from the project base-dir to the CWD
    localpath="$(normalize_relative "$go_to_before")"
    # Keep an absolute pathref for project dir too for libs not willing to
    # bother with or specify super-project refs, local name nuances etc.
    projdir="$(pwd -P)"
  } || {
    export localpath='' projdir=''
  }

  # Find workspace super-project, and then move back to this script's CWD
  go_to_dir_with .cllct/local.id && {

    # Workspace is a directory of projects, or a super project on its own.
    workspace=$(pwd -P)
    # Prefix is a relative path from the workspace base to the current projects
    # checkout.
    prefix="$(normalize_relative "$go_to_before")"
    test -z "$prefix" && error "prefix from go-to-before '$go_to_before'" 1
    test "$prefix" = "." || {

      # Add a little warning our records are incomplete
      grep -qF "$prefix"':' .projects.yaml || {
        warn "No such project prefix '$prefix'"
      }
      test "$verbosity" -ge 5 &&
      $LOG info "htd:load" "Workspace '$workspace' -> Prefix '$prefix'" >&2
      cd "$CWD"
    }
  } || {
    $LOG warn "htd:load" "No local workspace" >&2
    cd "$CWD"
  }

  # NOTE: other per-dir or project vars are loaded on a subcommand basis, e.g.
  # run flag 'p'.

  # TODO: clean up git-versioning app-id
  test -n "$APP_ID" -o ! -e .app-id || read -r APP_ID < .app-id
  test -n "$APP_ID" -o ! -e "$GITVER_ATTR" ||
      APP_ID="$(get_property "$GITVER_ATTR" "App-Id")"
  test -n "$APP_ID" -o ! -e .git ||
      APP_ID="$(basename "$(git config "remote.$vc_rt_def.url")" .git)"

  # TODO: go over above default-env and see about project-specific stuff e.g.
  # builddir and init parameters properly

  # Default locations for user-workspaces
  projectdirs="$(echo ~/project ~/work/*/)"

  test -e table.sha1 && R_C_SHA3="$(wc -l < table.sha1)"

  stdio_type 0
  test "$stdio_0_type" = "t" && {
    rows=$(stty size|awk '{print $1}')
    cols=$(stty size|awk '{print $2}')
  } || {
    rows=32
    cols=79
  }

  test -n "$htd_tmp_dir" || htd_tmp_dir="$(setup_tmpd)"
  test -n "$htd_tmp_dir" || error "htd_tmp_dir load" 1
  fnmatch "dev*" "$ENV" || {
    #rm -r "${htd_tmp_dir:?}"/*
    test "$(echo $htd_tmp_dir/*)" = "$htd_tmp_dir/*" || {
      rm -r $htd_tmp_dir/*
    }
  }

  htd_rules=$UCONFDIR/rules/$hostname.tab
  ns_tab=$UCONFDIR/namespace/$hostname.tab

  test -n "$htd_session_id" || htd_session_id=$(htd__uuid)

  # Process subcmd 'run' flags, single letter code triggers load/unload actions.
  # Sequence matters. Actions are predefined, or supplied using another subcmd
  # attribute. Action callbacks can be a first class function, or a literal
  # function name.
  local flags="$(try_value "${subcmd}" run htd | sed 's/./&\ /g')"
  test -z "$flags" -o -z "$DEBUG" || stderr debug "Flags for '$subcmd': $flags"
  for x in $flags
  do case "$x" in

    A ) # 'argsv' callback gets subcmd arguments, defaults to opt_arg.
    # Underlying code usually expects env arguments and options set. Maybe others.
    # See 'i'. And htd_inputs/_outputs env.
        test -n "$options" -a -n "$arguments" ||
            error "options/arguments env paths expected" 1
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
        debug "Exporting inputs '$(try_value inputs)' and outputs '$(try_value outputs)'"
        setup_io_paths -$subcmd-${htd_session_id}
        export ${htd__inputs?} ${htd__outputs?}
      ;;

    l )
        htd_subcmd_libs="$(try_value $subcmd libs htd)" ||
            htd_subcmd_libs=$subcmd

        lib_load $htd_subcmd_libs || return
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
        }
        test -n "$htd_subcmd_optsv" || htd_subcmd_optsv=htd_optsv
        test -e "$options" && {
          $htd_subcmd_optsv "$(cat $options)"
        } || true
      ;;

    P )
        local prereq_func="$(eval echo "\"\$$(echo_local $subcmd pre)\"")"
        test -z "$prereq_func" || $prereq_func $subcmd
      ;;

    p ) # set package file and id, update. But don't require, see q.
        # Set to detected PACKMETA file, set main package-id, and verify var
        # caches are up to date. Don't load vars.
        # TODO: create var cache per package-id. store in redis etc.
        test -n "$PACKMETA" -a -e "$PACKMETA" && {
            package_lib_set_local "$CWD" && update_package $CWD
            test -n "$package_id" && note "Found package '$package_id'"

        } || warn "No local package '$PACKMETA'"
      ;;

    q ) # set if not set, don't update and eval package main env
        test -n "$PACKMETA_SH" -a -e "$PACKMETA_SH" || {
            test -n "$PACKMETA" -a -e "$PACKMETA" &&
                note "Using package '$PACKMETA'" ||
                error "No local package" 5
            package_lib_set_local "$CWD" ||
                error "Setting local package ($CWD)" 6
        }

        # Evaluate package env
        . $PACKMETA_SH || error "local package" 7

        test "$package_type" = "application/vnd.org.wtwta.project" ||
                error "Project package expected (not $package_type)" 4
        test -n "$package_env" || export package_env=". $PACKMETA_SH"
        debug "Found package '$package_id'"
      ;;

    r ) # register package - requires 'p' first. Sets PROJECT Id and manages
        # cache updates for subcommand data.

        # TODO: query/update stats?
      ;;

    t ) # more terminal tooling: load shell and init
        lib_load shell
        shell_init
      ;;

    S )
        # Get a path to a storage blob, associated with the current base+subcmd
        S=$(try_value "${subcmd}" S htd)
        test -n "$S" \
          && status="$(setup_stat .json "" "${subcmd}-$(eval echo $S)")" \
          || status="$(setup_stat .json)"
        exec 5>$status.pkv
      ;;

    x ) # ignores, exludes, filters
        htd_load_ignores
      ;;

    *) error "No such run option ($subcmd): $x" 1 ;;

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
        jsotk.py -O yaml --pretty dump - < $report
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
  lst_init_ignores "" ignore
  #lst_init_ignores .names
  #match_load_table vars
}

# Set XSL-Ver if empty. See htd tpaths
htd_load_xsl()
{
  test -z "$xsl_ver" && {
    test -x "$(which saxon)" && xsl_ver=2 || xsl_ver=1
  }
  test xsl_ver != 2 -o -x "$(which saxon)" ||
      error "Saxon required for XSLT 2.0" 1
  info "Set XSL proc version=$xsl_ver.0"
}



# Static help echo's


htd__usage()
{
  htd_usage
}

htd_usage()
{
  echo "$scriptname.sh Bash/Shell script helper"
  echo 'Usage: '
  echo "  $scriptname <cmd> [<args>..]"
  echo ""
  echo "Possible commands are listed by help-commands or commands. "
  echo
  echo "See also: docs, todo"
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
  echo '  git-remote-info                  Show current ~/.conf/git/remote-dir/* vars.'
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
  echo '  docs                             Echo documentation (for CWD). '
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
  echo "  ~/.conf/etc/git/remotes/\$HTD_GIT_REMOTE.sh"
  echo "  ~/.conf/rules/\$host.sh"
  echo ''
  echo 'See dckr for container commands and vc for GIT related. '
}


htd_man_1__commands="List all commands"
htd__commands()
{
  choice_global='' choice_all=true std__commands
}

htd__libs_raw()
{
  locate_name $base
  note "Raw lib routine listing for '$fn' script"
  dry_run='' box_list_libs "$fn"
}

htd__libs()
{
  locate_name $base
  note "Script: '$fn'"
  box_lib "$fn"
  note "Libs: '$box_lib'"
}

htd_man_1__man='Access to built-in help strings

Man sections:
  1. (user) commands
  2. System calls
  3. Library Fuctions
  4. Devices and special files
  5. File formats and conventions
  6. Games, screensavers
  7. Miscellenea (overview, conventions, misc.)
  8. SysAdmin tools and Daemons
'
htd_spc__man='[Section] Id'
htd__man()
{
  std_man "$@"
}

htd_man_1__help="Echo a combined usage, command and docs. See also htd man and
try-help."
htd_spc__help="-h|help [<id>]"
htd__help()
{
  note "Listing all commands, see usage or composure"
  std_help "$@"
  info "Listing all commands, see usage or composure"
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
  test -z "$als" || { shift; set -- "$als" "$@" ; }
  {
    upper= mkvid "$*"
    # XXX: Retrieve and test for output-formats and quality factor
    #try_func $(echo_local "$vid" "" htd) &&

      # Print output format attribute value for field $*
      output_formats="$(try_value "$vid" of htd )" &&
        test -n "$output_formats"
  } && {
    echo $output_formats | tr ' ' '\n'
  } || {
    error "No sub-command or output formats for '$*'" 1
  }
}


htd_man_1__version="Version info"
htd__version()
{
  echo "$package_id/$version ($scriptname)"
}
#htd_als___V=version
htd_als____version=version
htd_run__version=p


htd__show()
{
  show_inner() { eval echo \"\$$1\"; }
  p= s= act=show_inner foreach_do "$@"
}


htd__home()
{
  htd__show HTDIR
}


htd__env_info()
{
  log "Script:                '$scriptname'"
  log "User Config Dir:       '$UCONFDIR' [UCONFDIR]"
  log "User Public HTML Dir:  '$HTDIR' [HTDIR]"
  log "Project ID:            '$PROJECT' [PROJECT]"
  log "Minimum filesize:      '$(( $MIN_SIZE / 1024 ))'"
  log "Editor:                '$EDITOR' [EDITOR]"
  log "Default GIT remote:    '$HTD_GIT_REMOTE' [HTD_GIT_REMOTE]"
  log "Ignored paths:         '$IGNORE_GLOBFILE' [IGNORE_GLOBFILE]"
}


htd_run__info=p
htd__info()
{
  test -n "$1" || set -- $(pwd -P)
  test -z "$2" || error "unexpected args '$2'" 1
  vc_getscm "$1" || return $?
  cd "$1"
  vc_info
}


htd__doctor()
{
  test -n "$package_pd_meta_tasks_document" -a -n "$package_pd_meta_tasks_done" && {
    true
    #map=package_pd_meta_ package_sh tasks_document
    #map=package_pd_meta_ package_sh tasks_document tasks_done

  } || stderr warning "Missing todo/done.txt env"

  info "Looking for empty files..."
  subcmd=find-empty htd__find_empty ||
      stderr ok "No empty files" && stderr warnning "Empty files above"

  # Go over named paths, see if there are any checks for its contexts
  #test -e "$ns_tab" && {

  #  info "Looking for contexts with 'checks' method..."
  #  fixed_table $ns_tab SID CONTEXTS | while read vars
  #  do
  #    eval local "$vars"
  #    upper=1 mkvid "$SID"
  #    echo $vid

  #  done
  #} || warn "No namespace table for $hostname"

  htd_prefix_names | while read -r prefix_name
  do
    base_path="$(eval echo \"\$$prefix_name\")"
    note "$prefix_name: $base_path"
  done
}


htd_man_1__fsck='Check file contents with locally found checksum manifests

Besides ck-validate and annex-fsck, look for local catalog.yml to validate too.
'
htd_run__fsck=i
htd__fsck()
{
  note "Running: ck_tab='*' htd ck..."
  # Go over local cksum/filename table files
  ck_tab='*' htd__ck || return $?

  note "Running checksums from all catalogs..."
  # Look for catalogdocs, go over any checksums there too
  ck_run_catalogs || return $?

  test -e .sync-rules.list && {

    note "Checking synchronized annex.."
    # Use sync-rules to mark annex (sub)repos as fsck-enable/disable'd
    subcmd=annex-fsck htd__annex_fsck || return $?

  } || {

    # Look for and fsck local annex as last step
    vc_getscm || return 0
    vc_fsck || return
    test -d "$scmdir/annex" && {
        note "Checking local annex.."
        git annex fsck . || return
    } || true
  }
}
htd_als__file_check=fsck


htd_man_1__make='Go to HTDIR, make target arguments'
htd__make()
{
  req_dir_env HTDIR
  cd $HTDIR && make "$@"
}
htd_of__make=list
htd_run__make=p
htd_als__mk=make


htd_man_1__expand='Expand arguments or lines on stdin to existing paths.

Default is to expand names with dir. set expand-dir to false to get names.
Provide `dir` to use instead of CWD. With no arguments stdin is default.
'
htd_spc__expand='expand [--dir=] [--(,no-)expand-dir] [GLOBS | -]'
htd_env__expand="dir="
htd_run__expand=eiAO
htd__expand()
{
  htd_expand "$@"
}


htd_man_1__edit_main="Edit the main script file(s), and add arguments"
htd_spc__edit_main="-E|edit-main [ -SREGEX | --search REGEX ] [ID-or-PATHS]"
htd__edit_main()
{
  htd_edit_main "$@"
}
htd_run__edit_main=piAO
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


htd_man_1__edit_local='Edit an existing local file, or abort.

TODO: The search term must match an existing component, or set grep/glob mode
to edit the first file.
'
htd_spc__edit_local="-e|edit [-g|--grep] [--glob] <search>"
htd_run__edit_local=iAO
htd__edit_local()
{
  test -n "$1" || error "search term expected" 1
  case "$1" in
    # NEW
    sandbox-jenkins-mpe | sandbox-mpe-new )
        cd $UCONFDIR/vagrant/sandbox-trusty64-jenkins-mpe
        $EDITOR Vagrantfile
        return $?
      ;;
    treebox-new )
        cd $UCONFDIR/vagrant/
        $EDITOR Vagrantfile
        return $?
      ;;
  esac

  local paths=$(pwd)
  #doc_path_args

  #find_paths="$(doc_find_name "$1")"
  #grep_paths="$(doc_grep_content "$1")"
  grep_paths="$(git grep -l "$1")"
  test -n "$find_paths" -o -n "$grep_paths" \
    || error "Nothing found to edit" 1

  case "$EDITOR" in
      # Execute search for Id, after editor opens.
      vim ) evoke="$evoke -c \"/$1\"" ;;
  esac
  eval $EDITOR $evoke $find_paths $grep_paths
}
htd_als__edit=edit-local
htd_als___e=edit-local


htd_man_1__find="Find file by name, or abort.

See also 'git-grep' and 'content' to search based on content.
"
htd_spc__find="-f|find <id>"
htd__find()
{
  test -n "$1" || error "name pattern expected" 1
  test -z "$2" || error "surplus argumets '$2'" 1

  note "Compiling ignores..."
  local find_ignores="$(find_ignores $IGNORE_GLOBFILE)"

  test -n "$FINDPATH" || {
    note "Looking in all volumes"
    FINDPATH=$(echo /srv/volume-[0-9]*-[0-9]* | tr ' ' ':')
  }

  lookup_path_list FINDPATH | while read v
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


htd_man_1__find_doc="Look for document.

TODO: get one document
"
htd_spc__find_doc="-F|find-doc (<path>|<localname> [<project>])"
htd__find_doc()
{
  doc_find "$@"
}
htd_als___F=find-doc
htd_run__find_doc=lx
htd_libs__find_doc=doc


htd_man_1__find_docs='Find documents

TODO: find doc-files, given local package metadata, rootdirs, and file-extensions
XXX: see doc-find-name
XXX: replace pwd basename strip with prefix compat routine
'
htd_spc__find_docs='find-docs [] [] [PROJECT]'
htd__find_docs()
{
  doc_find_all "$@"
}
htd_run__find_docs=pqlx
htd_libs__find_docs=doc


htd_man_1__volume='See htd volumes'
htd_man_1__volumes='Volumes

  volumes list - list volume paths
  also: ls-vol[umes]|list-volumes

  volumes check
  id DIR
'
htd_spc__volumes='volumes [--(,no-)catalog] [CMD]'
htd_env__volumes="catalog=true"
htd_of__volumes=list
htd_run__volumes=eiAO
htd__volumes()
{
  eval set -- $(lines_to_args "$arguments") # Remove options from args
  test -n "$1" || set -- list
  lib_load volume
  case "$1" in

    list ) shift ; htd_list_volumes "$@" ;;
    check ) shift ; htd_check_volumes "$@" ;;
    path?tab ) shift ; htd_path_names "$@" ;;
    treemap ) shift ; htd_volumes_treemap "$@" ;;

    id ) shift
        get_cwd_volume_id "$1"
      ;;

    * ) error "? '$*'" 1 ;;
  esac
}

htd_als__ls_vol=volumes\ list
htd_als__ls_volumes=volumes\ list
htd_als__list_volumes=volumes\ list


htd_man_1__copy='Copy script from other project. '
htd_spc__copy='copy Sub-To-Script [ From-Project-Checkout ]'
htd__copy() # Sub-To-Script [ From-Project-Checkout ]
{
  test -n "$2" || set -- "$1" $HOME/bin
  test -e "$2/$1" || {
    error "No Src $1 at $2" 1
  }
  test -e "$1" && {

    vimdiff "$1" "$2/$1" || return $?
  } || {
    local dir="$(dirname "$1")"
    test -z "$dir" || mkdir -vp $dir
    cp $2/$1 $1
    xsed_rewrite 's/Id:/From:/g' $1
    test ! -e .versioned-files.list || {
      echo "# Id: $(basename "$(pwd)")/" >> $1
      grep -F "$1" .versioned-files.list ||
        echo $1 >> .versioned-files.list
      git-versioning update
    }
    $EDITOR $1
  }
}



# Local or global context flow actions


htd_run__current=fpql
htd_libs__current=htd-list\ htd-tasks\ ctx-base
htd__current()
{
  htd_wf_ctx_sub current "$@"
}


htd_man_1__check='Update status

Run diagnostics for CWD and system.

- Show tags for which list buffers exist
- Check file names
- Check file contents (fsck, cksum)
'
htd_run__check=fpqil
htd_libs__check=ctx-base\ htd-check
htd__check()
{
  htd_wf_ctx_sub check "$@"
}

htd_als__chk=check


htd__init()
{
  htd_wf_ctx_sub init "$@"
}
htd_run__init=q


htd__list()
{
  htd_wf_ctx_sub list "$@"
}
htd_run__list=ql
htd_libs__list=list\ htd-list


htd_man_1__status='Quick context status

Per host, cwd info
'
htd_als__st=status
htd_als__stat=status
htd_run__status=ql
htd_libs__status=htd-list\ htd-tasks\ ctx-base
htd__status()
{
  htd_wf_ctx_sub status "$@"
}


htd_man_1__process='Process each item in list.  '
htd_spc__process='process [ LIST [ TAG.. [ --add ] | --any ]'
#htd_env__process=''
#htd_run__process=epqlA
htd_run__process=pql
htd_libs__process=htd-list\ htd-tasks\ ctx-base\ context
#htd_argsv__process=htd_argsv_list_session_start
htd_als__proc=process
htd_grp__process=proc

htd__process()
{
  htd_wf_ctx_sub process "$@"
}


htd_run__update=q
htd__update()
{
  htd_wf_ctx_sub update "$@"
}


#htd_man_1__update_status='Update quick status'
#htd_als__update_stats=update-status
#htd_run__update_status=f

#htd_als__update=update-checksums
#htd_als__update=update-status

#htd_run__status_cwd=fSm

htd__volume_status()
{
  htd__metadirs
}

# TODO: htd project status
htd__project_status()
{
  htd__metadirs
}

htd__workdir_status()
{
  htd__metadirs
  finfo.py --metadir .meta
}


htd_run__build=pq
htd__build()
{
  htd_wf_ctx_sub build "$@"
}


htd_man_1__clean='Look for things to clean-up in given directory

TODO: in sequence:
- check (clean/sync) SCM dir, keep bare repo in /srv/$scm-local
- existing archive: check unpacked and cleanup unmodified files
- finally (on archive itself, other files left),
  use `htd find` to find existing copies and de-dupe
'
htd_run__clean=pq
htd__clean()
{
  htd_wf_ctx_sub clean "$@"
}


htd_run__test=pq
htd__test()
{
  htd_wf_ctx_sub test "$@"
}


htd_man_1__metadirs='TODO find packages, .meta dirs, DB client/query local-bg

    volume-status
    project-status
    workdir-status
'
htd__metadirs()
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


htd_man_1__projects='Local project checkouts
  list
    TODO

  project-status
    See htd context
'
htd__projects()
{
  test -n "$1" || set -- list
  case "$1" in

    list ) shift
        cd $PDIR && find -L . -type d -maxdepth 1 \
            -exec test -e {}/.git \; -and -print | cut -c3-
      ;;

  esac
}


htd_man_1__project='Deal with project at local dir, see also projects.

  exists - check that project is vendored
  create - TODO: create new project
  checkout - TODO: create new checkout for project
  new - TODO: create new project
  init - TODO: check that project is vendored

  sync - TODO: ensure project is entirely available at vendor
  update - TODO: update from vendor(s)
  scm - TODO: init/update repo links
  releases - List github releases

Vendoring consists of selecting a vendor and using it as remote repository for
the project.
'
htd_run__project=p
htd__project()
{
  test -n "$1" || set -- info
  lib_load htd-project htd-src
  case "$1" in

    create ) shift ; htd_project_create "$@" ;;
    new ) shift ; htd_project_new "$@" ;;
    checkout ) shift ; htd_project_checkout "$@" ;;
    init ) shift ; htd_project_init "$@" ;;
    sync ) shift ; htd_project_sync "$@" ;;
    update ) shift ; htd_project_update "$@" ;;
    exists ) shift ; htd_project_exists "$@" ;;

    scm ) # Find local SCM references, add as remote for current/given project
        shift ; test -n "$1" || set -- "$(pwd)"
        test -d "$1" || error "Project directory missing '$1'" 1
        local name="$(basename "$1")"
        (
          cd "$1"
          vc_getscm || return 1
          # TODO: add remotes, either
          # bare personal project /srv/<scm>-*/<project>.<scm>
          # annex checkout /srv/annex-*/<project>
          # checkout at /src/<site>/<user>/<project> and /srv/project-local
          echo "/srv/$scm-"*"/$name.$scm" | tr ' ' '\n' | while read p ; do
            test -e "$p" || continue
            echo TODO: check for remote $p
          done
        )
      ;;

    check ) shift ; test -n "$1" || set -- "$(pwd)"
        test -d "$1" || error "Directory expected '$1'" 1
        htd__srv check-volume "$1" || return 1
        htd__project exists "$1" || return 1
        htd__project scm "$1" || return 1
      ;;

    releases ) shift ; test -z "$*" || error "Unexpected arguments"
        htd_project_releases
      ;;

    * ) error "? 'project $*'" 1 ;;
  esac
}


htd__go()
{
  test -n "$APP_ID" || error "App-Id required" 1
  test -n "$1" || set -- compile
  case "$1" in

    c | compile ) shift
        docker run --rm \
          -e CGO_ENABLED=true \
          -e COMPRESS_BINARY=true \
          -v "$(pwd -P):/src" \
          centurylink/golang-builder
        du -hs $APP_ID*

        htd__go exec "$@"
      ;;

    x | x-compile ) shift
        test -n "$os" || os="$(uname -s | tr 'A-Z' 'a-z')"
        test -n "$BUILD_GOOS" || BUILD_GOOS="$os"
        test -n "$BUILD_GOARCH" || {
            case "$mach" in

                x86_64 ) BUILD_GOARCH="amd64" ;;
                * ) BUILD_GOARCH="$arch" ;;
            esac
        }
        docker run --rm \
          -e CGO_ENABLED=true \
          -e COMPRESS_BINARY=true \
          -e BUILD_GOARCH="$BUILD_GOARCH" \
          -e BUILD_GOOS="$BUILD_GOOS" \
          -v "$(pwd -P):/src" \
          centurylink/golang-builder-cross
        du -hs $APP_ID*

        test -x "$APP_ID-$os-$BUILD_GOARCH" ||
            error "Golang x-compile failed to $os/$BUILD_GOARCH" 1

        test ! -e "./$APP_ID" || rm "./$APP_ID"
        ln -s "$APP_ID-$os-$BUILD_GOARCH" "$APP_ID"

        htd__go exec "$@"
      ;;

    exec ) shift
        ./$APP_ID "$@"
      ;;

    dockerize ) shift
        test -z "$1" || img_tag=$1
        test -n "$img_tag" || img_tag=bvberkum/$APP_ID
    test -e Dockerfile || { { cat <<EOM
FROM scratch
COPY $APP_ID /
ENTRYPOINT ["/$APP_ID"]
EOM
    } > Dockerfile; note "Placed default dockerfile"; }
        docker run --rm \
          -e CGO_ENABLED=true \
          -e COMPRESS_BINARY=true \
          -v "$(pwd -P):/src" \
          -v /var/run/docker.sock:/var/run/docker.sock \
          centurylink/golang-builder \
          $img_tag || return $?
        du -hs $APP_ID*
        note "Done $img_tag with $APP_ID"
      ;;

    * ) error "? 'go $*'" 1
      ;;
  esac
}


htd_man_1__validate='Validate JSON/YAML against JSON-Schema '
htd_spc__validate='validate DOC [SCHEMA]'
htd__validate()
{
  htd_schema_validate "$@"
}

htd_man_1__validate='Validate local package metadata aginst JSON-Schema '
htd_run__validate_package=p
htd__validate_package()
{
  set -- $scriptpath/schema/package.yml $scriptpath/schema/package.json
  test $2 -nt $1 || jsotk yaml2json --pretty "$@"
  htd_schema_validate .package.json "$2"
}

htd_man_1__validate_pdoc='Validate given projectdoc schema. '
htd__validate_pdoc()
{
  htd_schema_validate "$1" $scriptpath/schema/projectdir.yml
}


htd_man_1__tools='Tools manages simple installation scripts from YAML and is
usable to keep scripts in a semi-portable way, that do not fit anywhere else.

It works from a metadata document that is a single bag of IDs mapped to
objects, whose schema is described in schema/tools.yml. It can be used to keep
multiple records for the same binary, providing alternate installations for
the same tools.

  install [TOOL...]
  uninstall [TOOL...]
  installed [TOOL...]
  validate
  outline
    Transform tools.json into an outline compatible format.
  script

'
htd_run__tools=fl
htd_spc__tools="tools (<action> [<args>...])"
htd__tools()
{
  test -n "$1" || set -- list
  subcmd_default=list subcmd_prefs=${base}_tools_ try_subcmd_prefixes "$@"
}
htd_grp__tools=htd-tools

# FIXME: htd_als__install="tools install"
#htd_als__install=install-tool

htd_of__installed='yml'
htd_als__installed=tools\ installed

htd_als__outline=tools\ outline


htd_man_1__script="Get/list scripts in $HTD_TOOLSFILE. Statusdata is a mapping of
  scriptnames to script lines. See Htd run and run-names for package scripts. "
htd_spc__script="script"
htd_run__script=pSmr
htd_S__script=\$package_id
htd__script()
{
  # Force regeneration for stale data
  test $status -ot $HTD_TOOLSFILE \
    && { rm $status || true; }

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


htd__man_5__htdignore_merged='Exclude rules used by `htd find|edit|count`, compiled from other sources using ``htd init-ignores``. '

htd_man_1__init_ignores='Write all exclude rules to .htdignores.merged

TODO: see ignores, list and vs.
'
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
  test -e "$ns_tab" || warn "No namespace table for $hostname" 1
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
  test -e "$ns_tab" || warn "No namespace table for $hostname" 1
  fixed_table "$ns_tab" SID GROUPID | while read vars
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

# show/get/add htd shell aliases
htd__alias()
{
  htd_alias "$@"
}
htd_als__get_alias=alias
htd_als__set_alias=alias
htd_als__show_alias=alias


htd_man_1__edit_today='Edit todays log, an entry in journal file or dir

If argument is a file, a rSt-formatted date entry is added. For directories
a new entry file is generated, and symbolic links are updated.

TODO: accept multiple arguments, and global IDs for certain log dirs/files
TODO: maintain symbolic dates in files, absolute and relative (Yesterday, Saturday, 2015-12-11 )
TODO: revise to:

- Uses pd-meta.log setting from package, or JRNL_DIR env.
- Updates symbolic entries and keys
- Gets editor session
- Adds date entry or file boilerplate, keeps boilerplate checksum
- Starts editor
- Remove unchanged boilerplate (files), or add changed files to GIT
'
htd__edit_today()
{
  lib_load doc htd-doc
  htd_edit_today "$@"
}
htd_run__edit_today=p
htd_als__vt=edit-today


htd__edit_week()
{
  note "Editing $1"
  {
    htd_edit_week
  } || {
    error "ERR: $1/ $?" 1
  }
}
htd_als__vw=edit-week
htd_als__ew=edit-week
htd_grp__edit_week=cabinet


htd_man_1__archive_path='
# TODO consolidate with today, split into days/week/ or something
'
htd_spec__archive_path='archive-path DIR PATHS..'
htd__archive_path()
{
  test -n "$1" || set -- cabinet/
  test -d "$1" || {
    fnmatch "*/" "$1" && {
      error "Dir $1 must exist" 1
    } || {
      test -d "$(dirname "$1")" ||
        error "Dir for base $1 must exist" 1
    }
  }
  fnmatch "*/" "$1" || set -- "$1/"

  Y=/%Y M=-%m D=-%d archive_path "$1"

  datelink -1d "$archive_path" ${ARCHIVE_DIR}yesterday$EXT
  echo yesterday $datep
  datelink "" "$archive_path" ${ARCHIVE_DIR}today$EXT
  echo today $datep
  datelink +1d "$archive_path" ${ARCHIVE_DIR}tomorrow$EXT
  echo tomorrow $datep

  unset archive_path archive_path_fmt datep target_path
}
# declare locals for unset
htd_vars__archive_path="Y M D EXT ARCHIVE_BASE ARCHIVE_ITEM datep target_path"
htd_grp__archive_path=cabinet


# update yesterday, today and tomorrow and all current, prev and next weekday links
htd__today() # Jrnl-Dir YSep MSep DSep [ Tags... ]
{
  htd_jrnl_day_links "$@"
  htd_jrnl_period_links "$1" "$2"
}
htd_grp__today=cabinet


htd__week_nr()
{
  expr $(date +%U) + 1
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
htd_grp__this_week=cabinet


htd_man_1__jrnl="Handle rSt log entries at archive formatted paths

TODO: status check update
  list [ Prefix=2... ]
      List entries with prefix, use current year if empty. Set to * for
      listing everything.
  entries
      XXX: resolve metadata
"
htd__jrnl()
{
  test -n "$1" || set -- status
  case "$1" in

    status ) note "TODO: '$*'"
      ;;

    check ) note "TODO: '$*'"
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
htd_grp__jrnl=cabinet

htd_of__jrnl_json='json-stream'
htd__jrnl_json()
{
  test -n "$1" || set -- $JRNL_DIR/entries.list
  htd__txt to-json "$1"
}
htd_grp__jrnl_json=cabinet


# TODO: use with edit-local
htd__edit_note()
{
  htd_edit_note "$@"
}
htd_als__n=edit-note
htd_grp__edit_note=cabinet

htd__edit_note_nl()
{
  htd__edit_note "$1" "$2 nl" || return $?
}
htd_als__nnl=edit-note-nl
htd_grp__edit_note_nl=cabinet

htd__edit_note_en()
{
  htd__edit_note "$1" "$2 en" || return $?
}
htd_als__nen=edit-note-en
htd_grp__edit_note_en=cabinet


htd_man_1__main_doc_paths='Print candidates for main document
'
htd__main_doc_paths()
{
  lib_load doc
  local candidates="$(doc_main_files)"
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
htd_grp__main_doc_paths=cabinet


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
htd_run__main_doc_edit=p
htd_als__md=main-doc-edit
htd_als___E=main-doc-edit
htd_grp__main_doc_edit=cabinet



### VirtualBox

vbox_names=~/.conf/etc/vbox/vms.sh
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
htd_grp__vbox=vm

htd__vbox_start()
{
  test -n "$1" || error "VM name required" 1
  htd__vbox $1
  VBoxManage startvm ${uuid} --type headless \
      || error "Headless-start of VM $name" 1 \
      && log "Headless-start of VM $name completed successfully"
}
htd_grp__vbox_start=vm

htd__vbox_start_console()
{
  test -n "$1" || error "VM name required" 1
  htd__vbox $1
  VBoxManage startvm ${uuid} \
      || error "Console-start of VM $name" 1 \
      && log "Console-start of VM $name completed successfully"
}
htd_grp__vbox_start_console=vm

htd__vbox_reset()
{
  test -n "$1" || error "VM name required" 1
  htd__vbox $1
  VBoxManage controlvm ${uuid} reset \
      || error "Reset of VM $name" 1 \
      && log "Reset of VM $name completed successfully"
}
htd_grp__vbox_start_reset=vm

htd__vbox_stop()
{
  test -n "$1" || error "VM name required" 1
  htd__vbox $1
  VBoxManage controlvm ${uuid} poweroff \
      || error "Power-off of VM $name" 1 \
      && log "Power-off of VM $name completed successfully"
}
htd_grp__vbox_stop=vm

htd__vbox_suspend()
{
  test -n "$1" || error "VM name required" 1
  htd__vbox $1
  VBoxManage controlvm ${uuid} savestate \
      || error "Save-state of VM $name" 1 \
      && log "Save-state of VM $name completed successfully"
}
htd_grp__vbox_suspend=vm

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
htd_grp__vbox_list=vm

htd__vbox_running()
{
  VBoxManage list runningvms
}
htd_grp__vbox_running=vm

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
htd_grp__vbox_info=vm

htd__vbox_gp()
{
  htd__vbox "$1"
  VBoxManage guestproperty enumerate ${uuid}
  #VBoxManage guestproperty get ${uuid} "/VirtualBox/GuestInfo/Net/0/V4/IP"
}
htd_grp__vbox_gp=vm


# Wake a remote host using its ethernet address
wol_hwaddr=~/.conf/wol/hosts-hwaddr.sh
htd__wol_list_hosts()
{
  cat $wol_hwaddr
  error "Expected hostname argument" 2
}
htd_grp__wol_list_hosts=box

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
htd_grp__wake=box


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
htd_grp__shutdown=box


htd__ssh_vagrant()
{
  test -d $UCONFDIR/vagrant/$1 || error "No vagrant '$1'" 1
  cd $UCONFDIR/vagrant/$1
  vagrant up || {
    vagrant up --provision || {
      warn "Provision error $?. See htd edit to review Vagrantfile. "
      sys_confirm "Continue with SSH connection?" ||
          note abort 1
    }
  }
  vagrant ssh
}


htd_run__ssh=f
htd__ssh()
{
  test -d $UCONFDIR/vagrant/$1 && {

    htd__ssh_vagrant "$@"
    return $?
  }

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
htd_grp__ssh=box


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
htd_grp__up=box


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
htd_grp__detect_ping=box


# Simply list ARP-table, may want something better like arp-scan or an nmap
# script
htd__mac()
{
  arp -a
}
htd_grp__mac=box


htd_man_1__random_str="Print a web/url-save case-sensitive Id of length. It is
 base64 encoded, so multiples of 3 make sense as length, or they will be padded
 to length. "
htd_spc__random_str='(rndstr|random-str) [12]'
htd_als__rndstr=random-str
htd__random_str()
{
  test -n "$1" || set -- 12 # Set default htd:random-str length
  python -c "import os, base64;print base64.urlsafe_b64encode(os.urandom($1))"
}
htd_grp__random_str=box


htd_man_1__txt='todo.txt/list.txt util
'
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
htd_run__tasks=iqtlAO
htd_libs__tasks=htd-tasks\ tasks
htd__tasks() { false; }


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
htd_run__tasks_edit=epqlA
htd_libs__tasks_edit=htd-tasks
htd_argsv__tasks_edit=htd_argsv_tasks_session_start
htd_als__edit_tasks=tasks-edit
htd_grp__tasks_edit=tasks


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
htd_run__tasks_hub=eqiAOl
htd_libs__tasks_hub=tasks\ htd-tasks
htd_grp__tasks_hub=tasks
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
htd_run__tasks_process=lA
htd_libs__tasks_process=htd-tasks
htd_argsv__tasks_process=htd_argsv_tasks_session_start
htd_als__tasks_proc=tasks-process
htd_als__process_tasks=tasks-process
htd_grp__tasks_process=tasks


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
htd_run__tasks_buffers=l
htd_libs__tasks_buffers=htd-tasks
htd_grp__tasks_buffers=tasks


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
  info "3.1. Env: $(var2tags \
    id todo_slug todo_document todo_done tags buffers add_files locks colw)"
  set -- $todo_document $todo_done
  assert_files $1 $2
  # Get tags too for current todo/done file, to get additional locks
  tags="$(tasks_todotxt_tags "$1" "$2" | lines_to_words ) $tags"
  note "Session-Start Tags: ($(echo "$tags" | count_words
    )) $(echo "$tags" )"
  info "3.2. Env: $(var2tags \
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

htd__gtasks_lists()
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


htd_man_1__urls='Grep URLs from plain text.

  urls [encode|decode] ARGS...
    Quote/unquote query, fragment or other URL name parts.
  urls list FILE
    Scan for URLs in text file
  urls get [-|URI-Ref]
    Download
  urls todotxt FILE [1|EXT]
    Output matched URLs enclosed in angled brackets, set 1 to reformat file
    and EXT to backup before rewrite.
  urls urlstat [--update] LIST [Init-Tags]
    Add URLs found in text-file LIST to urlstat index, if not already recorded.
    With update, reprocess existing entries too.

'
htd_run__urls=fl
htd_libs__urls=web
htd__urls()
{
  test -n "$1" || set -- list
  subcmd_prefs=${base}_urls_\ urls_ try_subcmd_prefixes "$@"
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
htd_grp__save_url=annex


htd_man_1__git='

  info
    Compile some info on checkouts (remote names and URLs) in $PROJECTS.

  find <user>/<repo>
    Look in all /srv/scm-git for repo.

  req|require <user>/<repo> [Check-Branch]
    See that checkout for repo is available, print path. With branch or other
    version check version of checkout as well.

  get <user>/<repo> [Version]
    Create or upate repo at /srv/scm-git, then make checkout at $VND_GH_SRC.
    Link that to $PROJECT_DIR.

  get-env [ENV] <user>/<repo> [Version]
    Make a reference checkout in a new subdir of $SRC_LOCAL and set it to commit
    or Env-Ver.

Helpers

  list
    Find repo checkouts in $PROJECTS.
  scm-list
    Find bare repos in $PROJECTS_SCM.
  scm-find <user>/<repo>
    Looks for (partial) [<user>/]<repo>.git (glob pattern) in SCM basedirs.
  scm-get VENDOR <user>/<repo>
    Create bare repo from vendor.
  src-get VENDOR <user>/<repo>
    Create checkout from local SCM. Fix remote to vendor, and $PROJECT_DIR
    symlink.

FIXME: cleanup below

    git-remote
    git-init-local
    git-init-remote
    git-drop-remote
    git-init-version
    git-missing
    git-init-src
    git-list
    git-files
    git-grep
    git-features
    gitrepo
    git-import

See also:

    htd vcflow
    vc
'


htd_man_1__gitremote='List repos at remote (for SSH), or echo remote URL.

    TODO: list
    list-for-ns Ns-Name

    TODO: hostinfo [ Remote-Name | Remote-ID ]
        Get host for given remote name or remote-dir Id.


TODO: match repositories for user/host with remote providers (SSH dirs, GIT
servers)
'
htd__gitremote()
{
  local remote_dir= remote_hostinfo= remote_name=
  lib_load gitremote

  test -n "$*" || set -- "$HTD_GIT_REMOTE"

  # Insert empty arg if first represents remote-dir sh-props file
  test -e $UCONFDIR/etc/git/remotes/$1.sh -a $# -le 2 && {
    # Default command to 'list' when remote-id exists and no further args given
    test $# -eq 1 && set -- "list" "$@" || set -- url "$@"
  }

  test -n "$1" || set -- list
  subcmd_prefs=gitremote_ try_subcmd_prefixes "$@"
}



htd__git_init_local() # [ Repo ]
{
  local remote=local
  repo="$(basename "$(pwd)")"
  [ -n "$repo" ] || error "Missing project ID" 1

  BARE=/srv/scm-git-local/$NS_NAME/$repo.git
  [ -d $BARE ] || {
      log "Creating temp. bare clone"
      git clone --bare . $BARE
    }

  remote_url="$(git config remote.$remote.url)"
  test -n "$remote_url" && {
    test "$remote_url" = $BARE || error "$remote not $BARE just created" 1
  } || {
    git remote add $remote $BARE
  }
}

htd__git_init_remote() # [ Repo ]
{
  [ -e .git ] || error "No .git directory, stopping remote init" 0
  test -n "$HTD_GIT_REMOTE" || error "No HTD_GIT_REMOTE" 1
  local repo= remote=$HTD_GIT_REMOTE BARE=

  # Create local repo if needed
  htd__git_init_local || warn "Error initializing local repo ($?)"

  # Remote repo, idem.
  local $(htd__gitremote sh-env "$remote" "$repo")
  {
    test -n "$remote_hostinfo" && test -n "$remote_repo_dir"
  } ||
    error "Incomplete env" 1

  ssh_cmd="mkdir -v $remote_repo_dir"
  ssh $remote_hostinfo "$ssh_cmd" && {

    log "Syning new bare repo to $remote_scp_url"
    rsync -azu $BARE/ $remote_scp_url

  } ||
    warn "Remote exists, checking remote '$remote'"

  # Initialise remotes for checkout
  {
    echo $remote $remote_scp_url
    echo local $BARE
    echo $hostname $hostname.zt:$BARE
  } | while read rt rurl
  do
    url="$(git config --get remote.${rt}.url)"
    test -n "$url" && {
      test "$rurl" = "$url" || {
        warn "Local remote '$rt' does not match '$rurl'"
      }
    } || {
      git remote add $rt $rurl
      git fetch $rt
      log "Added remote $rt $rurl"
    }
  done
}

htd__git_drop_remote()
{
  [ -n "$1" ] && repo="$1" || repo="$PROJECT"
  log "Checking if repo exists.."
  ssh_opts=-q
  htd__gitremote | grep $repo || {
    error "No such remote repo $repo" 1
  }
  source_git_remote # FIXME
  log "Deleting remote repo $remote_user@$remote_host:$remote_dir/$repo"
  ssh_cmd="rm -rf $remote_dir/$repo.git"
  ssh -q $remote_user@$remote_host "$ssh_cmd"
  log "OK, $repo no longer exists"
}

htd__git_init_version()
{
  local readme="$(echo [Rr][Ee][Aa][Dd][Mm][Ee]"."*)"

  test -n "$readme" && {
    fnmatch "* *" "$readme" && { # Multiple files
      warn "Multiple Read-Me's ($readme)"
    } ||
      note "Found Read-Me ($readme)"

  } || {
    readme=README.md
    {
      echo "Version: 0.0.1-dev"
    } >$readme
    note "Created Read-Me ($readme)"
  }

  grep -i '\<version\>[\ :=]*[0-9][0-9a-zA-Z_\+\-\.]*' $readme >/dev/null && {

    test -e .versioned-files.list ||
      echo "$readme" >.versioned-files.list
  } || {

    warn "no verdoc, TODO: consult scm"
  }

  # TODO: gitflow etc.
  git describe ||
    error "No GIT description, tags expected" 1
}


# List everything in  HTD_GIT_REMOTE repo collection

# Warn about missing src or project
htd__git_missing()
{
  test -d /srv/project-local || error "missing local project folder" 1
  test -d /srv/scm-git-local || error "missing local git folder" 1

  htd__gitremote | while -r read repo
  do
    test -e /srv/scm-git-local/$repo.git || warn "No src $repo" & continue
    test -e /srv/project-local/$repo || warn "No checkout $repo"
  done
}

# Create local bare in /src/
htd__git_init_src()
{
  test -d /srv/scm-git-local || error "missing local git folder" 1

  htd__gitremote | while read repo
  do
    fnmatch "*annex*" "$repo" && continue
    test -e /srv/scm-git-local/$repo.git || {
      git clone --bare $(htd git-remote $repo) /srv/scm-git-local/$repo.git
    }
  done
}


htd_man_1__git_list='List files at remove, or every src repo for current Ns-Name
'
htd__git_list()
{
  test -n "$1" || set -- $(echo /src/*/$NS_NAME/*.git)
  for repo in $@
  do
    echo $repo
    git ls-remote $repo
  done
}

htd_man_1__git_files='List or look for files'
htd_spc__git_files='git-files [ REPO... -- ] GLOB...'
htd_run__git_files=ia
htd__git_files()
{
  local pat="$(compile_glob $(lines_to_words $arguments.glob))"
  read_nix_style_file $arguments.repo | while read repo
  do
    cd "$repo" || continue
    note "repo: $repo"
    # NOTE: only lists files at HEAD branch
    git ls-tree --full-tree -r HEAD |
        awk '{print $NF}' |
        sed 's#^#'"$repo"':HEAD/#' | grep "$pat"
  done
}
htd_argsv__git_files=arg-groups-r
htd_arg_groups__git_files="repo glob"
#htd_defargs_repo__git_files=/src/*/*/*/
htd_defargs_repo__git_files=/srv/scm-git-local/$NS_NAME/*.git


htd_man_1__git_grep='Run git-grep for every repository.

To run git-grep with bare repositories, a tree reference is required.

With `-C` interprets argument as shell command first, and passes ouput as
argument(s) to `git grep`. Defaults to `git rev-list --all` output (which is no
pre-run but per exec. repo).

If env `repos` is provided it is used iso. stdin.
Or if `dir` is provided, each "*.git" path beneath that is used. Else uses the
arguments.

If stdin is attach to the terminal, `dir=/src` is set. Without any
arguments it defaults to scanning all repos for "git.grep".

TODO: spec
'
htd_spc__git_grep='git-grep [ -C=REPO-CMD ] [ RX | --grep= ] [ GREP-ARGS | --grep-args= ] [ --dir=DIR | REPOS... ] '
htd_run__git_grep=iAO
htd__git_grep()
{
  eval set -- $(lines_to_args "$arguments") # Remove options from args
  test -n "$grep" || { test -n "$1" && { grep="$1"; shift; } || grep='\<git.grep\>'; }

  test -n "$grep_args" -o -n "$grep_eval" && {
    note "Using env args:'$grep_args' eval:'$grep_eval'"
  } || {

    trueish "$C" && {
      test -n "$1" && {
        grep_eval="$1"; shift
      }
    }

    test -n "$1" && { grep_args="$1"; shift; } || { #grep_args=master
        trueish "$all_revs" && {
          grep_eval='$(git br|tr -d "*\n")'
        } ||
          grep_eval='$(git rev-list --all)';
      }
  }

  note "Running ($(var2tags grep C grep_eval grep_args))"
  gitrepos "$@" | { while read repo
    do
      {
        info "$repo:"
        cd $repo || continue
        test -n "$grep_eval" && {
          eval git --no-pager grep -il "'$grep'" "$grep_eval" || { r=$?
            test $r -eq 1 && continue
            warn "Failure in $repo ($r)"
          }
        } || {
          git --no-pager grep -il "$grep" $grep_args || { r=$?
            test $r -eq 1 && continue
            warn "Failure in $repo ($r)"
          }
        }
      } | sed 's#^.*#'$repo'\:&#'
    done
  }
  #| less
  note "Done ($(var2tags grep C grep_eval grep_args repos))"
}


htd_man_1__gitrepo='List local GIT repositories

Arguments are passed to htd-expand, repo paths can be given verbatim.
This does not check that paths are GIT repositories.
Defaults effectively are:

    --dir=/srv/scm-git-local/$NS_NAME *.git``
    --dir=/srv/scm-git-local/$NS_NAME -

Depending on wether there is a terminal or pip/file at stdin (fd 0).
'
htd_spc__gitrepo='gitrepo [--(,no-)expand-dir] [--repos=] [--dir=] [ GLOBS... | PATHS.. | - ]'
htd_env__gitrepo="dir="
htd_run__gitrepo=eiAO
htd__gitrepo()
{
  eval set -- $(lines_to_args "$arguments") # Remove options from args
  info "Running '$*' ($(var2tags grep repos dir stdio_0_type))"
  gitrepos "$@"
}


htd__git_import()
{
  test -d "$1" || error "Source dir expected" 1
  note "GIT import from '$1'..."
  find $1 | cut -c$(( 2 + ${#1}))- | while read pathname
  do
    test -n "$pathname" || continue
    test -d "$1/$pathname" && mkdir -vp "$pathname"
    test -L "$pathname" && continue
    test -f "$pathname" || continue
    trueish "$dry_run" && {
      echo mv -v "$1/$pathname" "$pathname"
    } || {
      mv -v "$1/$pathname" "$pathname"
    }
  done
}

htd_libs__git=git\ htd-git
htd_run__git=l
htd__git()
{
  test -n "$1" || set -- info
  subcmd_prefs=${base}_git_\ git_ try_subcmd_prefixes "$@"
}


htd_man_1__file='TODO: Look for name and content at path; then store and cleanup.

    newer-than
    older-than
    newest
    mtype
    mtime
    mtime-relative
    size PATH
      Bytesize
    info PATH
      Use magic tests to describe file format
    mime PATH
      Try to give MIME content-type by using magic tests
    drop PATHS...
      Remove contents/path, wether untracked or GIT / Annexed tracked.
    find-by-sha2list
    find-by-sha256e

Given path, find matching from storage using name, or content. On match, compare
and remove path if in sync.
'
htd_run__file=fl
htd__file()
{
  test -n "$1" || set -- info
  subcmd_prefs=${base}_file_\ file_ try_subcmd_prefixes "$@"
}
htd_als__test_name=file\ test-name
htd_als__file_info=file\ format
htd_als__file_modified=file\ mtime
htd_als__file_born=file\ btime
htd_als__file_mediatype=file\ mtype
htd_als__file_guessmime=file\ mtype
htd_als__drop=file\ drop
htd_als__filesize_hist=file\ size-histogram
htd_als__filenamext=file\ extensions
htd_als__filestripext=file\ stripext

htd_als__wherefrom=wherefrom



htd__content()
{
  note "TODO: go over some ordered CONTENTPATH to look for local names.."
}


htd_man_1__date='

    relative TIMESTAMP
    fmt-dawin TAGS STRF
    fmt DATESTR STRF
    microtime
    iso
    autores DATESTR
    parse DATESTR [FMT]
    tstat
    pstat TSTAT
    touchdt [FILE | TIMESTAMP]
    touch [FILE | TIMESTAMP FILE]
'
htd_run__date=fl
htd_libs__date=date\ htd-date
htd__date()
{
  test -n "$1" || set -- relative
  subcmd_prefs=date_\ htd_date_\ fmtdate_ try_subcmd_prefixes "$@"
}


htd_man_1__vcflow='
TODO: see also vc gitflow
'
htd_libs__vcflow=vcflow\ htd-vcflow
htd_run__vcflow=fl
htd__vcflow()
{
  test -n "$1" || set -- status
  subcmd_prefs=${base}_vcflow_ try_subcmd_prefixes "$@"
}
htd_als__gitflow_check_doc=vcflow\ check-doc
htd_als__gitflow_check=vcflow\ check
htd_als__gitflow=vcflow\ status
htd_als__feature_branches=vcflow\ list-features



htd_man_1__source='Generic sub-commands dealing with source-code. For Shell
specific routines see also `function`.

  source lines FILE [ START [ END ]]        Copy (output) from line to end-line.
  expand-source-line FILE LINENR
    Replace a source line with the contents of the sourced script

    This must be pointed to a line with format:

      .\ (P<sourced-file>.*)
'
htd__source()
{
  test -n "$1" || set -- copy
  case "$1" in

    lines ) shift
        test -e "$1" || error "file expected '$1'" 1
        source_lines "$@" || return $?
      ;;
    line ) shift
        test -e "$1" || error "file expected '$1'" 1
        source_line "$@" || return $?
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

    where-grep-before ) shift
        file_where_before "$@" || return $?
        echo $line_number
      ;;

    where-grep-tail ) shift
        file_where_grep_tail "$@" || return $?
        echo $line_number
      ;;

    # XXX: ... No wrappers yet
    file-insert-at ) fail TODO ;;
    file-replace-at ) fail TODO ;;
    file-insert-where-before ) fail TODO ;;
    split-file-where-grep ) fail TODO ;;
    truncate ) fail TODO ;;
    truncate-lines ) fail TODO ;;
    # NOTE: see also htd function subcommand
    func-comment ) fail TODO ;;
    header-comment ) fail TODO ;;
    backup-header-comment ) fail TODO ;;
    list-functions ) fail TODO ;;
    # And many more in src.lib.sh

    expand-sentinel ) shift
        where_line="$(grep -nF "# htd source copy-paste: $2" "$1")"
        line_number=$(echo "$where_line" | sed 's/^\([0-9]*\):\(.*\)$/\1/')
        test -n "$line_number" || return $?
        expand_sentinel_line "$1" $line_number || return $?
      ;;
    expand-source-line ) shift ; expand_source_line "$@" ;;
    expand-include-sentinels ) shift ; expand_include_sentinels "$@" ;;

    * ) error "'$1'?" 1
      ;;
  esac
}


htd_man_1__function='Operate on specific functions in Sh scripts.

   copy FUNC FILE
     Retrieves function-range and echo function including envelope.
   copy-paste [ --{,no-}copy-only ] FUNC FILE
     Remove function from source and place in seperately sourced file
   start-line
     Retrieve line-number for function.
   range
     Retrieve start- and end-line-number for function.

See also
    src
    sync-func(tion)|diff-func(tion) FILE1 FUNC1 DIR[FILE2 [FUNC2]]
    sync-functions|diff-functions FILE FILE|DIR
    diff-sh-lib [DIR=$scriptpath]
'
htd__function() { false; }
htd_run__function=l
htd_libs__function=htd-function


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

  lib_load functions

  # Extract both functions to separate file, and source at original scriptline
  mkid "$1" "" "_-" ; ext="$(filenamext "$1")"
  cp_board= ext="$id.$ext" copy_paste_function "$2" "$1" || { r=$?
    error "copy-paste-function 1 ($r)"
    return $r
  }
  test -s "$cp" || error "copy-paste file '$cp' for '$1:$2' missing" 1
  src1_line=$start_line ; start_line= ; src1=$cp ; cp=
  mkid "$3" "" "_-" ; ext="$(filenamext "$3")"
  cp_board= ext="$id.$ext" copy_paste_function "$4" "$3" || { r=$?
    # recover after error
    expand_source_line $1 $src1_line || error "expand-source-line 1" $?
    error "copy-paste-function 2 ($r)"
    return $r
  }
  test -s "$cp" || error "copy-paste file '$cp' for '$3:$4' missing" 1
  src2_line=$start_line ; start_line= ; src2=$cp ; cp=

  # Edit functions side by side
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
      diff "$src1" "$src2"
      stderr ok "'$2'"
    }
  }
  trueish "$quiet" || {
    diff -bqr "$src1" "$src2" >/dev/null 2>&1 &&
    stderr debug "synced '$*'" ||
    stderr warn "not in sync '$*'"
  }

  trueish "$copy_only" || {
    # Move functions back to scriptline
    expand_source_line "$1" $src1_line || error "expand-source-line 1" $?
    expand_source_line "$3" $src2_line || error "expand-source-line 2" $?
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
htd_als__sync_func=sync-function


htd_man_1__diff_functions="List all functions in FILE, and compare with FILE|DIR

See diff-function for behaviour.
"
htd__diff_functions() # FILE FILE|DIR
{
  test -n "$1" || error "diff-functions FILE FILE|DIR" 1
  test -n "$2" || set -- "$1" $scriptpath
  test -e "$2" || error "Directory or file to compare to expected '$2'" 1
  test -f "$2" || set -- "$1" "$2/$1"
  test -e "$2" || { info "No remote side for '$1'"; return 1; }
  test -z "$3" || error "surplus arguments: '$3'" 1
  lib_load functions
  functions_list $1 | sed 's/\(\w*\)()/\1/' | sort -u | while read -r func
  do
    grep -bqr "^$func()" "$2" || {
      warn "No function $func in $2"
      continue
    }
    htd__diff_function "$1" "$func" "$2" ||
        warn "Error on '$1:$func' <$2> ($?)" 1
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
  See {sync,diff}-functions for options'
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
    htd__sync_functions $lib $1 || continue
  done
}
htd_run__diff_sh_lib=iAO


htd__find_empty()
{
  test -n "$1" || set -- .
  test -d "$1" || error "Dir expected '$?'" 1
  info "Compiling ignores..."
  local find_ignores="$(find_ignores $IGNORE_GLOBFILE)"
  test -n "$find_ignores" || fail "Cannot compile find-ignores"
  eval find $1 -false $find_ignores -o -empty -a -print
}

htd__find_empty_dirs()
{
  test -n "$1" || set -- .
  test -d "$1" || error "Dir expected '$?'" 1
  info "Compiling ignores..."
  local find_ignores="$(find_ignores $IGNORE_GLOBFILE)"
  test -n "$find_ignores" || fail "Cannot compile find-ignores"
  eval find $1 -false $find_ignores -o -empty -a -type d -a -print
}

htd_als__largest_files=find-largest
htd__find_largest() # Min-Size
{
  test -n "$1" || {
    set -- 15
    note "Set min-size to $1MB"
  }
  # FIXME: find-ignores
  test -n "$find_ignores" || {
    test -n "$2" && find_ignores="$2" || find_ignores="-not -iname .git "
  }
  eval find . \\\( $find_ignores \\\) -a -size +${MIN_SIZE}c -a -print | head -n $1
}

htd_als__filesize=file\ size


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
  } || true

}


# TODO: rename helper, group in lib. Or drop for renameutils?

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
  lib_load match
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

# XXX: cleanup
htd_host_arg()
{
  test -z "$1" && host=$1 || host=${hostname}
}

# TODO: pre-process file/metadata
htd__resolve()
{
  set --
}

htd_man_1__update_checkout='Checkout/update GIT version for this $scriptpath

Without argument, pulls the currently checked out branch. With env `push` turned
on, it completes syncing with the remote by returning the branch with a push.

If "all" is given as remote, it expands to all remote names.
'
htd_env__update_checkout='push'
htd_spc__update_checkout='update [<commit-ish> [<remote>...]]'
htd__update_checkout()
{
  test -n "$1" ||
      set -- "$(cd $scriptpath && git rev-parse --abbrev-ref HEAD)" $@
  test -n "$2" || set -- "$1" "$vc_rt_def"
  test "$2" = "all" &&
    set -- "$1" "$(cd $scriptpath && git remote | tr '\n' ' ')"

  # Perform checkout, pull and optional push
  test -n "$push" || push=0
  (
    cd $scriptpath
    local branch=$1 ; shift ; for remote in $@
    do
      # Check argument is a valid existing branch on remote
      git checkout "$branch" &&
      git show-ref | grep '\/remotes\/' | grep -qF $remote'/'$branch && {
        git pull "$remote" "$branch"
        trueish $push && git push "$remote" "$branch" || true
      } || {
        warn "Reference $remote/$branch not found, skipped" 1
      }
    done
  )
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
  eval set -- $(lines_to_args "$arguments") # Remove options from args
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


htd_man_1__cabinet='Manage files, folders with perma-URL style archive-paths

  cabinet add [--{not-,}-dry-run] [--archive-date=] REFS..
    Move path to Cabinet-Dir, preserving timestamps and attributes. Use filemtime
    for file unless now=1.

        <refs>...  =>  <Cabinet-Dir>/%Y/%m/%d-<ref>...

Env
    CABINET_DIR $PWD/cabinet $HTDIR/cabinet
'
htd_spc__cabinet='cabinet [CMD ARGS..]'
htd__cabinet()
{
  cabinet_req
  eval set -- $(lines_to_args "$arguments") # Remove options from args
  subcmd_prefs=${base}_cabinet_\ cabinet_ try_subcmd_prefixes "$@"
}
htd_grp__cabinet=cabinet
htd_run__cabinet=ilAO
htd_argsv__cabinet()
{
  opt_args "$@"
}


# Move paths into new dir
htd__mkdir() # Dir Paths...
{
  test ! -e "$1" || error new-path 1
  local destd=$1 ; shift
  mkdir -p "$destd"
  while test $# -gt 0
  do
    mv $1 $destd/$1
    shift
  done
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
htd_grp__save=annex


htd_man_1__tags='
  bookmarks

XXX: see also
  task-hub
        List tags for which local task buffers or backend/proc scripts exists.
'
htd__tags()
{
  test -n "$1" || set -- bookmarks
  case "$1" in

    bookmarks ) shift
        width=$(tput cols)
        cols=$(( $width / 16 ))
        bookmarks.py tags "$@" | pr -t -$cols -w $width
      ;;

    nodes )
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
      ;;

    * ) error "tags '$*'?" ;;
  esac
}


htd__save_ref()
{
  test -n "$1" || error "tags expected" 1
  tags="$1"

  shift 1
  for ref in "$@"
  do
    echo TODO: save $ref
  done
}
htd_grp__save_ref=annex


htd_man_1__package='Get local (project/workingdir) metadata

  package ls|list-ids
     List package IDs from local package metadata file.
  package update
     Regenerate main.json/PackMeta-JS-Main and package.sh/PackMeta-Sh files from YAML
  package write-script NAME
     Write env+script lines to as-is executable shell script for "scripts/NAME"
  package write-scripts NAMES
     Write scripts.
  package remotes-init
     Take all repository names/urls directly from YAML, and create remotes or
     update URL for same in local repository. The remote name and exact
     remote-url is determined with htd-repository-url (htd.lib.sh).
  package remotes-reset
     Remove all remotes and reset
  package urls
     TODO: List URLs for package.
  package openurl|open-url [URL]
     ..
  package debug
     Log each Sh package settings.
  package scripts-write [NAME]
     Compile script into as-is shell script.

Plumbing
  package sh-script SCRIPTNAME [PackMeta-JS-Main]
     List script lines
  package sh-env
     List profile script lines from PackMeta-Sh
  package sh-env-script
     Update env profile script from sh-env lines

  package dir-get-key <Dir> <Package-Id> [<Property>...]

Plumbing commands dealing with the local project package file. See package.rst.
These do not auto-update intermediate artefacts, or load a specific package-id
into env.
'
htd_run__package=iAOpq
htd__package()
{
  eval set -- $(lines_to_args "$arguments") # Remove options from args
  test -n "$*" && {
      test -n "$1" || {
        shift && set -- debug "$@"
      }
    } || set -- debug
  subcmd_prefs=${base}_package_\ package_ try_subcmd_prefixes "$@"
}

htd_man_1__ls="List local package names"
htd_als__ls=package\ list-ids

htd_man_1__openurl="Open local package URL"
htd_als__openurl=package\ open-url



htd_man_1__topics='List topics'
htd__topics()
{
  test -n "$1" || set -- list
  subcmd_prefs=${base}_topics_\ topics_ try_subcmd_prefixes "$@"
}
htd_run__topics=iAOpx

htd_man_1__list_topics='List topics'
htd_als__list_topics="topics list"



htd_man_1__scripts='Action on local package "scripts".

  scripts names [GLOB]
    List local package script names, optionally filter by glob.
  scripts list [GLOB]
    List local package script lines for names
  scripts run NAME
    Run scripts from package

'
htd_run__scripts=pfl
htd_libs__scripts='package htd-scripts'
htd__scripts()
{
  test -n "$1" || set -- names
  subcmd_prefs=${base}_scripts_ try_subcmd_prefixes "$@"
}

htd_run__script_opts=iAOpfl
htd_libs__script_opts='package htd-scripts'
htd__script_opts()
{
  eval set -- $(lines_to_args "$arguments") # Remove options from args
  htd__scripts "$@"
}


htd_man_1__run='Run script from local package.y*ml. See scripts (run).'
htd_spc__run='run [SCRIPT-ID [ARGS...]]'
htd_run__run=iAOpl
htd_libs__run='htd-scripts'
htd__run()
{
  # List scriptnames when no args given
  test -z "$1" && {
    note "Listing local script IDs:"
    htd__scripts names
    return 1
  }
  eval set -- $(lines_to_args "$arguments") # Remove options from args
  htd_scripts_run "$@"
}


htd_man_1__list_run="list lines for package script. See scripts (list)."
htd__list_run()
{
  verbose_no_exec=1 htd_scripts_list "$@"
}
htd_run__list_run=iAOql
htd_libs__list_run='package htd-scripts'



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
        htd_tasks_buffers $TARGET "$@" | while read buffer
        do test -e "$buffer" || continue; echo "$buffer"; done

        target_files= targets= max_age=
        #targets="$(htd_prefix_expand $TARGETS "$@")"
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
          $LOG ok pre-proc "CMD=$CMD RT=$RT TARGETS=$TARGETS CWD=$CWD CTX=$CTX" >&2
      ;;

    update | post-proc ) shift
        test -n "$3" || set -- "$1" "$2" 86400
        # TODO: place record in each context. Or rather let backends do what
        # they want with the ret/stdout/stderr.
        note "targets: '$TARGETS'"
        for target in $TARGETS
        do
          scr="$(htd_tasks_buffers "$target" | grep '\.sh$' | head -n 1)"
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
htd_grp__rules=rules
#htd_als__edit_rules='rules edit'
htd__edit_rules()
{
  $EDITOR $htd_rules
}
htd_grp__edit_rules=rules
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
htd_grp__period_status_files=rules


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
htd_grp__run_rules=rules


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
    test "$out_fmt" = "json" && { echo "]" ; } || true
  }
}
htd_of__show_rules='plain csv yaml json'
htd_grp__show_rules=rules


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
htd_grp__rule_target=rules


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
htd_run__storage=plA
htd_libs__storage=htd-tasks
htd_argsv__storage=htd_argsv_tasks_session_start
htd_grp__storage=rules


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
htd_grp__get_backend=rules


htd__extensions()
{
  lookup_test="test -x" lookup_path HTD_EXT $1.sh
}
htd_grp__extensions=rules


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
  #subcmd_prefs=try_subcmd_prefixes "$@"
  case "$1" in
    fixed-hd ) shift ;     grep_list_head "$@" ;;
    fixed-hd-ids ) shift ; fixed_table_hd_ids "$@" ;;
    fixed-cuthd ) shift ;  fixed_table_cuthd "$@" ;;
    fixed ) shift ; f      ixed_table "$@" ;;
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
  lib_load match
  match_name_vars $@
}

htd__name_tags()
{
  local pattern
  lib_load match
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
  lib_load match
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
htd_grp__name_tags_all=meta


htd_spc__update_checksums="update-checksums [TABLE_EXT]..."
htd__update_checksums()
{
  test -n "$1" || set -- ck sha1 md5
  local failed=$(setup_tmpf .failed)
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
htd_grp__update_checksums=meta


# Checksums frontend


htd_man_1__ck='Validate given table-ext, ck-files, or default table.$ck-exts set

Arguments are files with checksums to validate, or basenames and extensions to
check. With no file given, checks table.*
'
htd_spc__ck='ck [CK... | TAB...]'
htd__ck()
{
  local exts= ck_files=
  test -z "$*" && {
    exts="$ck_exts"
  }
  test -e "$1" && {
      ck_files="$*"
  } || {
    exts="$( for a in "$@" ; do \
      test -e "$a" && continue || echo "$a"; done | lines_to_words)"
    ck_files="$(ck_files "." $exts)"
  }

  for tab in $ck_files
  do
    # Skip unexpanded names and non-existing checksum tables
    test -e "$tab" || continue
    ck_run $tab || return $?
  done
}

htd_man_1__ck_add='Add new entries but dont hash'
htd_spc__ck_add="ck TAB [PATH|.]"
htd_grp__ck_add=meta
htd__ck_add()
{
  test -n "$1" || error "Need table to update" 1
  ck_run_update "$@" || error "ck-update '$1' failed" 1
}

htd_grp__ck_init=meta
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
htd_grp__ck_table=meta
# Either check table for path, or iterate all entries. Echoes checksum, two spaces and a path
htd__ck_table()
{
  lib_load match
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
htd_grp__ck_table_subtree=meta
htd__ck_table_subtree()
{
  lib_load match
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

htd_grp__ck_update=meta
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

htd_grp__ck_drop=meta
htd__ck_drop()
{
  lib_load match
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

htd_grp__ck_validate=meta
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
htd_grp__cksum=meta

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
htd_grp__ck_prune=meta

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
htd_grp__ck_consolidate=meta

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
htd_grp__ck_clean=meta

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
htd_grp__ck_metafile=meta



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
htd_grp__ck_torrent=media



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
htd_grp__mp3_validate=media



htd__mux()
{
  test -n "$1" || set -- "docker-"
  test -n "$2" || set -- "$1" "dev"
  test -n "$3" || set -- "$1" "$2" "$(hostname -s)"

  note "tmuxinator start $1 $2 $3"
  tmuxinator start $1 $2 $3
}
htd_grp__mux=tmux


htd_man_1__tmux='Unless tmux is running, get a new tmux session, based on the
current environment TMUX_SOCK and/or a name in TMUX_SDIR. See `htd tmux get`.

If tmux is running with an environment matching the current, attach. Different
tmux environments are managed by using seperate sockets per session.

Matching to a socket is done per user, an by the values of env vars set with
Htd-TMux-Env. By default it tracks hostname and CS (color-scheme light or dark).
::

    <TMux-SDir>/tmux-<User-Id>/htd<Env-Var-Names>

Ohter commands deal with

Start tmux, tmuxinator or htd-tmux with given names.
TODO: first deal with getting a server and session. Maybe later per window
management.

  tmux list-sockets | sockets
    List (active) sockets of tmux servers. Each server is a separate env with
    sessions and windows.

  tmux list [ - | MATCH ] [ FMT ]
    List window names for current socket/session. Note these may be empty, but
    alternate formats can be provided, ie. "#{window_index}".

  tmux list-windows  [ - | MATCH ] [ FMT ]

  tmux get [SESSION-NAME [WINDOW-NAME [CMD]]]
    Look for session/window with current selected server and attach. The
    default name arguments may dependent on the env, or default to Htd/bash.
    Set TMUX_SOCK or HTD_TMUX_ENV+env to select another server, refer to
    tmux-env doc.

  tmux current | current-session | current-window
    Show combined, or session name, or window index for current shell window

  tmux show TMux Var-Name
  tmux stuff Session Window-Nr String
  tmux send Session Window-Nr Cmd-Line

  tmux resurrect
    See tmux-resurrect for help on dumpfiles.
'
htd__tmux()
{
  tmux_env_req 0
  test -n "$1" || set -- get

  case "$1" in
    list-sockets | sockets ) shift ; htd_tmux_sockets "$@" || return ;;
    list ) shift ; htd_tmux_list_sessions "$@" || return ;;
    list-windows ) shift ; htd_tmux_session_list_windows "$@" || return ;;
    current-session ) shift ; tmux display-message -p '#S' || return ;;
    current-window ) shift ; tmux display-message -p '#I' || return ;;
    current ) shift ; tmux display-message -p '#S:#I' || return ;;

    # TODO: find a way to register tmux windows by other than name; PWD, CMD
    # maybe need to record environment profiles per session
    show ) shift ; $tmux show-environment "$@" || return ;;

    stuff ) shift ; $tmux send-keys -t $1:$2 "$3" || return ;;
    send ) shift ; $tmux send-keys -t $1:$2 "$3" enter || return ;;

    resurrect ) shift ; htd__tmux_resurrect "$@" || return ;;

    * ) subcmd_prefs=${base}_tmux_ try_subcmd_prefixes "$@" || return ;;
  esac

  # TODO: cleanup old tmux setup
  #while test -n "$1"
  #do
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
htd_als__tmux_list=tmux\ list-sessions
htd_als__tmux_sessions=tmux\ list-sessions
htd_als__tmux_windows=tmux\ session-list-windows
htd_als__tmux_session_windows=tmux\ session-list-windows


htd_man_5__tmux_resurrect='The tmux-resurrect dumps come as a line-based
file format, with three types of lines: several windows, and panes for windows,
and a state line.

1       2    3      4           5     6    7    8  9     10    11
Window: Name Index  active-idx? bits? layout/geom?
Pane:   Name Index? Colon-Title num? bits? num? Pwd num? name? Cmd
State:  Window-Names?
'

htd_man_1__tmux_resurrect='Manage local tmux-resurrect sessions and configs
(tmux.lib.sh). See htd help tmux.

Env
    $TMUX_RESURRECT ~/.tmux/resurrect

Commands
    list
        Print basenames of all dumps on local box.
    lastname
        Print name of most recent dump.
    panes [Dumpfile]
        Line up window, pane, pwd and command for every dumpfile ever or given.
    names
        Print basenames plus list of window names for all dumps on local box.
    listwindows [Dumpfile]
        List window names (for last session)
    allwindows
        List all names, for every window ever
    table
        Tabulate panel counts for every window.
    info [Window [Dumpfile]]
        Print table or look for window panes in every dumpfile ever.
    drop [last]
        Remove dumpfile and reset
    reset
        Restore "last" link. If no dumpfile is found, call restore first.
    backup-all
        Move all dumpfiles except last to cabinet.
    restore [Date|last]
        Find last

See tmux-resurrect in section 5. (file-formats) for more details.
'
htd__tmux_resurrect()
{
  test -n "$1" || set -- lastname
  subcmd_prefs=tmux_resurrect_ try_subcmd_prefixes "$@"
}


htd_man_1__test='Alias for run test TODO: or pd test'
htd_als__test="run test"
#htd_man_1__test="Run PDir tests in HTDIR"
#htd__test()
#{
#  req_dir_env HTDIR
#  cd $HTDIR && projectdir.sh test
#}
htd_als___t=test
#htd_grp__test=projects


htd_man_1__edit_test="Edit all BATS spec-files (test/*-spec.bats)"
htd__edit_test()
{
  $EDITOR ./test/*-spec.bats
}
htd_als___T=edit-test
htd_grp__edit_test=cabinet


htd_man_1__inventory="Edit all inventories"
htd__inventory()
{
  req_dir_env HTDIR
  test -e "$HTDIR/personal/inventory/$1.rst" && {
    set -- "personal/inventory/$1.rst" "$@"
  } || {
    set -- "personal/inventory/main.rst" "$@"
  }
  htd_rst_doc_create_update $1 "Inventory: $1"
  htd_edit_and_update $@
}
htd_als__inv=inventory
htd_grp__inventory=cabinet


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
htd_grp__inventory_electronics=cabinet


htd__uptime()
{
  nowts="$($gdate +"%s")"
  s=$(${os}_uptime)
  note "Last reboot: $( fmtdate_relative "$nowts" "$s" )"

  ts_rel_multi "$s" hours minutes seconds
  note "Uptime: $dt_rel"
}


htd_man_1__disk='Enumerate disks '
htd__disk()
{
  lib_load disk htd-disk $os || return
  test "$uname" = Linux && {
    test -e /proc || error "/proc/* required" 1
  }
  test -n "$1" || set -- list
  subcmd_prefs=${base}_${os}_disk_\ ${base}_disk_\ disk_ try_subcmd_prefixes "$@"
}

htd_als__runtime=disk\ runtime
htd_als__bootnumber=disk\ bootnumber


htd__disks()
{
  test -n "$rst2xml" || error "rst2xml required" 1
  sudo which parted 1>/dev/null && parted=$(sudo which parted) \
    || warn "No parted" 1
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

htd_man_1__disk_doc='
    list
    list-local
        See disk.sh

    update
        XXX: maybe see disk.sh about updating catalog
    sync
        Create/update JSON doc, with details of locally available disks.
    doc
        Generate JSON doc, with details of locally available disks.
'
htd_run__disk_doc=f
htd__disk_doc()
{
  test -n "$1" || set -- list
  case "$1" in

      list|list-local ) disk.sh $1 || return $? ;;

      update ) ;;
      sync )  shift
           os_disk_list | while read dev
           do
             {
               disk_local "$dev" NUM DISK_ID || continue
             } | while read num disk_id
             do
               echo "disk_doc '$dev' $num '$disk_id'"
             done
           done
        ;;

      doc ) disk_doc "$@" || return $?
        ;;

  esac
}


htd__create_ram_disk()
{
  test -n "$1" || set -- "RAM disk" "$2"
  test -n "$2" || set -- "$1" 32
  test -z "$3" || error "Surplus arguments '$3'" 1

  note "Creating/updating RAM disk '$1' ($2 MB)"
  create_ram_disk "$1" "$2" || return
}


htd__normalize_relative()
{
  normalize_relative "$1"
}


# Get document part using xpath. See getxl about getting document's XML
htd__getx() # Document XPath-Expr Document-XML
{
  test -n "$1" || error "Document expected" 1
  test -e "$1" || error "No such document <$1>" 1
  test -n "$2" || error "XPath expr expected" 1

  test -n "$3" || set "$1" "$2" "$(du_getxml "$1")"

  xmllint --xpath "$2" "$3"
  rm "$3"
}


htd_man_1__tpaths='List topic paths (nested dl terms) in document paths'
htd_load__tpaths="xsl"
htd__tpaths()
{
  test -n "$1" || error "At least one document expected" 1
  test -n "$print_src" || local print_src=0
  test -n "$print_baseid" || local print_baseid=0

  test $# -gt 1 && {
      act=du_dl_term_paths foreach_do "$@"
      return $?
    } || {
      du_dl_term_paths "$@"
      return $?
    }
}
htd_vars__tpaths="path rel_leaf root xml"


htd_load__tpath_raw="xsl"
htd__tpath_raw()
{
  test -n "$1" || error "document expected" 1
  test -e "$1" || error "no such document '$1'" 1

  act=du_dl_term_paths_raw foreach_do "$@"
}


htd_man_1__xproc='Process XML using xsltproc - XSLT 1.0'
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


htd_man_1__xproc2='Process XML using Saxon - XSLT 2.0'
htd__xproc2()
{
  {
    fnmatch '<* *>' "$2" && {
      # TODO: hack saxon to ignore offline DTD's
      # https://www.scriptorium.com/2009/09/ignoring-doctype-in-xsl-transforms-using-saxon-9b/
      saxon - $1 <<EOM
$2
EOM
    } || {
      test -e "$1" || error "no file for saxon: '$1'" 1
      saxon -dtd "$1" "$2" || return $?
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


gcal_tab=~/htdocs/personal/google-.tab
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


htd_man_1__port='List command, pid, user, etc. for open port'
htd__port()
{
  case "$uname" in
    Darwin ) ${sudo}lsof -i :$1 || return ;;
    Linux ) ${sudo}netstat -an $1 || return ;;
  esac
}


htd__active='
  files
    TODO: cache set of user-files
'
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


htd_man_1__ps='Using ps, print properties for the given or current process.
'
htd_spc__ps='ps PID'
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
    stderr warn TODO 1
  } || {
    htd__current_paths || return
  }
}

htd_als__c=current-paths
htd_als__of=open-paths
htd_als__lsof=open-paths
htd_als__open_files=open-paths


htd_man_1__current_paths='List open paths for user (belonging to shells)'
htd__current_paths() # User Cmd-Grep Cmd-Len
{
  test -n "$1" || set -- $(whoami) "$2" "$3"
  test -n "$2" || set -- "$1" '/^(bash|sh|ssh|dash|zsh)$/x' "$3"
  test -n "$3" || set -- $1 "$2" "15"

  lsof +c $3 -c $2 -u "$1" -a -d cwd |
      tail -n +2 | awk '{print $9}' | sort -u
}
htd_of__current_paths='list'
htd_als__open_paths=current-paths


htd_man_1__open_paths='Lists names of currently claimed by a process.

    dirs
        Print directories only
    files
        Print directories only
    paths
        Print just the directory and fila paths.
    pid-paths
        Print process ID, parent process ID, inode and name.
    info
        Print process ID, parent process ID, command, offset, inode and name.
    details
        Print process ID, parent process ID, command, offset, access mode,
        lock status, device node, descriptor, inode and name.

Open paths (from lsof), even filtered by user, returns 10k paths on my OSX box.
It even lists network file connections. For it to get usable, need to limit
it to known bases.

Also unfortenately, my editor (vim) does not keep the files open, but
instead the swap file. Making identification just a bit more complicated.
And finally, query lsof takes quite a long time, making it completely
unsuited for interactive use.

Because of this, using find -newer is a more efficient way to find paths to
user files. As for open directories, htd prefixes records those based on
current-cwd. Somehow, current-cwd is also significantly faster getting live
data than open-paths lsof invocations.
'
htd__open_paths()
{
  test -n "$1" -a -n "$2" || set -- "paths" "$1"
  test -n "$1" || set -- "paths" "$2"
  test -n "$2" || set -- "paths" "."
  test_dir "$2" || return $?
  note "Listing open paths for '$2'"
  set -- "$1" "$(cd "$2" && pwd -P)"
  case "$1" in

    dirs ) shift ; htd__open_paths paths "$1"  | filter_dirs - ;;
    paths ) shift ; lsof -F n +D "$1" | grep -v '^p' | cut -c2- | sort -u ;;

    pid-paths ) shift
          lsof -F pRin0 +D "$1" | tr '\0' ' '
        ;;

    info ) shift
          lsof -F pRcoin0 +D "$1" | tr '\0' ' '
        ;;

    details ) shift
          lsof -F pRcoaldfin0 +D "$1" | tr '\0' ' '
        ;;
  esac
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
    htd__current_paths >$lsof

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

# List paths newer than recent-paths setting
htd__recent_paths()
{
  test -n "$1" || set -- "$(pwd -P)"
  note "Listing active paths under $1"
  dateref=$(statusdir.sh file recent-paths)
  find $1 -newer $dateref
}



## Prefixes: named paths, or aliases for base paths

htd_man_1__prefixes='Manage local prefix table and index, or query cache.

  (op|open-files)
    Default command. Pipe htd current-cwd to htd prefixes names.
    Set htd_path=1 to get full paths with prefix/localname pairs outputted in
    one line.

Read from table
  list
    List prefix varnames from table.
  table | raw-table
    Print user or default prefix-name lookup table
  table-id
    Print table filename

Lookup with table
  name Path-Name
    Resolve to real, absolute path and echo <prefix>:<localpath> by scanning
    prefix index.
  names (Path-Names..|-)
    Call name for each line or argument.
  pairs (Path-Names..|-)
    Get both path and name for each line or argument.
  expand (Prefix-Paths..|-)
    Expand <prefix>:<local-path> back to to absolute path.
  op
    Feed Htd-current-paths through htd-prefixes-names

Cache
  cache
    List cached prefixes and paths beneath them.
  update [TTL=60min [<persist=false>]]
    Update cache, read below.
  current
    List but dont update, this is essentially the same as htd-prefixes-op but
    tailored for htd-update-prefixes.

Other
  check
    TODO htd prefixes check ..

See prefix.rst for design and use-cases.

# Cache
Cache has two parts. An in-memory index, for tracking current prefixes,
and the local paths beneath prefixes. And secondary a persisted part, where a
cumulative tree of all prefixes/paths for a certain period is stored. And where
individual cards are kept per path, with timestamps.

The in-memory parts are updated every run of `update`.
Paths are kept in memory for TTL seconds after they closed, to allow recalling
them during that time.

If there is a change, the persisted document is not updated. Only until some
path TTL expires and is dropped from the index is the persisted document updated
automatically. Otherwise, a persist to secondary storage is only requested by
invocation argument.

Updating the first cache requires checking and possibly changing two lists.
For the secondary, several JSON documents are created: one with the entire tree
and current time, and if needed one for each path, setting a new ctime.
This setup prevents conflicts in distributed stores, but it leaves the task of
cleaning up old trees and ctimes documents.


TODO: track path timestamp, keep for X amount of time in index
TODO: clear indices on certain (global) context switches: day, domain
TODO: check for services, redis is required. couch can be offline for a bit
TODO: update registry atime/utime once cache elapses?

'
htd__prefixes()
{
  test -n "$index" || local index=
  test -s "$index" || req_prefix_names_index

  test -n "$1" || set -- op
  case "$1" in

    # Read from table
    table-id ) shift ;       echo $UCONFDIR/$pathnames ; test -e "$pathnames" || return $? ;;
    raw-table ) shift ;      cat $UCONFDIR/$pathnames || return $? ;;
    table )                  htd_path_prefix_names || return $? ;;
    list )                   htd_prefix_names || return $? ;;

    # Lookup with table
    name ) shift ;           htd_prefix "$1" || return $? ;;
    names ) shift ;          htd_prefixes "$@" || return $? ;;
    pairs ) shift ;          htd_path_prefixes "$@" || return $? ;;
    expand ) shift ;         htd_prefix_expand "$@" || return $? ;;

    # Update/fetch from cache
    cache )                  htd_list_prefixes || return $? ;;
    update )                 htd_update_prefixes || return $? ;;
    current )
        htd__current_paths | htd_path_prefixes - |
          while IFS=' :' read path prefix localpath
        do
          trueish "$htd_act" && {
            older_than $path $_1HOUR && act='- ' || act='+ '
          }

          trueish "$htd_path" &&
              echo "$act$path" || echo "$act$prefix:$localpath"
        done
      ;;

    op | open-files ) shift
        htd__current_paths | htd_prefixes -
      ;;

    check )
        # Read index and look for env vars
        htd_prefix_names | while read name
        do mkvid "$name"
            #val="${!vid}"
            val="$( eval echo \"\$$vid\" )"
            test -n "$val" || warn "No env for $name"
        done
      ;;
  esac
} # End prefixes

htd_als__prefix=prefixes

htd_of__prefixes_list='plain text txt rst yaml yml json'
htd_als__prefixes_list=prefixes\ list
htd_als__list_prefixes=prefixes\ list

htd_of__prefixes_update='txt rst plain'
htd_als__prefixes_update=prefixes\ update
htd_als__update_prefixes=prefixes\ update



## Services

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
        echo "#$(grep_list_head "$HTD_SERVTAB")"
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


htd__clean_empty_dirs()
{
  htd__find_empty_dirs "$1" | while read p
  do
    rmdir -p "$p" 2>/dev/null
  done
}




htd_man_1__archive='Deal with archive files (tar, zip)

  test-unpacked ARCHIVE [DIR]
    Given archive, note files out of sync
  clean-unpacked ARCHIVE [DIR]
  note-unpacked ARCHIVE [DIR]
'
htd__archive()
{
  test -n "$1" || set -- status
  subcmd_prefs=${base}_archive_ try_subcmd_prefixes "$@"
}
htd_run__archive=fl
htd_libs__archive=archive\ htd-archive

#htd_env__clean_unpacked='P'

htd_als__archive_list=archive\ list
htd_als__test_unpacked=archive\ test-unpacked
htd_als__clean_unpacked=archive\ clean-unpacked
htd_als__note_unpacked=archive\ note-unpacked




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
        local output="$B/$(htd_prefix "$1").xhtml"
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


# Control 'say' command (BSD/Darwin)
htd__say()
{
  lang=$1
  shift
  test -n "$s" || s=f
  case "$lang" in
    uk ) case "$s" in m ) say -v Daniel "$@" ;; f ) say -v Kate "$@" ;; esac;;
    us ) case "$s" in m ) say -v Alex "$@" ;; f ) say -v Samantha "$@" ;; esac;;
    dutch | nl ) case "$s" in m ) say -v Xander "$@" ;; f ) say -v Claire "$@" ;; esac;;
    japanese | jp ) case "$s" in m ) say -v Otoya "$@" ;; f ) say -v Kyoko "$@" ;; esac;;
    chinese | cn | sc ) say -v Ting-Ting "$@" ;; hong-kong | sar | tc ) say -v Sin-ji "$@" ;;
  esac
}


htd_man_1__src='TODO: this is for the src service/directory

  linespan Start-Line[/- ]Lines File [Checks]
    Retrieve content. Provided checksums to validate files before.

  (content | linerange) Start-Line[- ]End-Line File [Checks]
    Convert range to to span and defer execution to linespan.

  validate File Checks..
    Require one/each/all checksums to be valid. Checksums can be abbreviated
    (abbrev=7). See ck-<CK> for more details.

  grep-to-first Grep File From-Line
    ..

See source for src.lib.sh wrapped as subcommands.
'
htd__src()
{
  test -n "$1" || set -- list
  case "$1" in

    linespan ) shift ;
        note "'$*'"
        { fnmatch "*-*" "$1" || fnmatch "*/*" "$1"
        } && { r="$1" ; shift ; set -- $(echo "$r" | tr '/-' ' ') "$@" ; }
        sl=$1 l=$2 file=$3 ; shift 3
        test -z "$1" || { htd__src validate "$file" "$@" || return ; }
        tail -n +$sl $file | head -n $l
      ;;

    content | linerange ) shift ;
        fnmatch "*-*" "$1" &&
            { r="$1" ; shift ; set -- $(echo $r | tr '-' ' ') "$@" ;}
        sl=$1 el=$2 file=$3 ; shift 3
        htd__src linespan $sl $(( $el - $sl + 1 )) "$file" "$@"
      ;;

    grep-to-first ) shift ; grep_to_first "$@" ; echo $first_line ;;
    grep-to-previous ) shift ; grep_to_last "$@" ; echo $prev_line ;;

    validate ) shift ;
        file=$1 ; shift
        while test $# -gt 0
        do
          echo "$1  $file"
          shift
        done | any=1 ck_validate
      ;;

    * ) error "'$1'?" 1 ;;
  esac
}
htd_run__src=f


htd__domain()
{
  note "Domain User ID: "$(cat $(statusdir.sh file domain-identity))
  note "Domain Net ID: "$(cat $(statusdir.sh file domain-network))
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

  find-volumes | volumes [SUB]
      List volume container ids (all or with name SUB)

  check
  check-volume Dir
      Verify Dir as either service-container or entry in one.
  list
  update
  init
      ..
  -instances
      List unique local service-containers (FIXME: ignore local..)
      Plumping for a grep on ls output
  -names
      List unique service-name part for all local service-containers only.
      Plumbing for a grep on -instances
  -paths [SUB]
      Like -vpaths, but for every service container, not just the roots.
  -vpaths [SUB]
      List all existing volume paths, or existing SUB paths (all absolute, with sym. parts)
      Plumbing for shell glob-expansion on all local volume container links,
      checking if any given SUB, lower-case SId of SUB, or title-case of SId
      exists as path.
  -disks [SUB]
      List all existing volume-ids with mount-point, or existing SUB paths.
      See -vpaths, except this returns disk/part index and `pwd -P` for each dir.
'
htd__srv()
{
  test -n "$1" || set -- list
  case "$1" in

    -instances ) shift
        ls /srv/ | grep -v '^\(\(.*-local\)\|volume-\([0-9]*-[0-9]*-.*\)\)$'
      ;;

    -names ) shift
        htd__srv -instances | sed '
            s/^\(.*\)-[0-9]*-[0-9]*-[a-z]*-[a-z]*$/\1/g
            s/^\(.*\)-local$/\1/g
          ' | sort -u
      ;;

    -paths ) shift
        for p in /srv/*/
        do
          htd__name_exists "$p" "$1" || continue
          echo "$p$name"
        done
      ;;

    -vpaths ) shift
        for p in /srv/volume-[0-9]*-[0-9]*-*-*/ ; do
          htd__name_exists "$p" "$1" || continue
          echo "$p$name"
        done
      ;;

    -disks ) shift
        htd__srv -vpaths "$1" | while read vp ; do
          echo $(echo "$vp" | cut -d '-' -f 2-3 | tr '-' ' ') $(cd "$vp" && pwd -P)
        done
      ;;

    find-volumes | volumes ) shift
        htd__srv -vpaths "$1" | cut -d'/' -f3 | sort -u
      ;;

    check ) shift
        # For all local services, we want symlinks to any matching volume path
        htd__srv -names | while read name
        do
          test -n "$name" || error "name" 1
          #htd__srv find-volumes "$name"
          htd__srv -paths "$name"
          #htd__srv -vpaths "$name"

          # TODO: find out which disk volume is on, create name and see if the
          # symlink is there. check target maybe.
        done
      ;;

    check-volume ) shift ; test -n "$1" || error "Directory expected" 1
        test -d "$1" || error "Directory expected '$1'" 1
        local name="$(basename "$1")"

        # 1. Check that disk for given directory is also known as a volume ID

        # Match absdir with mount-point, get partition/disk index
        local abs="$(absdir "$1")"
        # NOTE: match with volume by looking for mount-point prefix
        lib_load match
        local dvid=$( htd__srv -disks | while read di pi dp ; do
            test "$dp" = "/" && p_= || match_grep_pattern_test "$dp";
            echo "$1" | grep -q "^$p_\/.*" && { echo $di-$pi ; break ; } || continue
          done )

        #  Get mount-point from volume ID
        local vp="$(echo "/srv/volume-$dvid-"*)"
        local mp="$(absdir "$vp")"
        test -e "$vp" -a -n "$dvid" -a -e "$mp" ||
            error "Missing volume-link for dir '$1'" 1

        # 2. Check that directory is either a service container, or directly
        #    below one. Warn, or fail in strict-mode.

        # NOTE: look for absdir among realpaths of /srv/{*,*/*}

        test "$abs" = "$mp" && {
          true # /srv/volume-*
        } || {

          # Look for each SUB element, expect a $name-$dvid symbol
          local sub="$(echo "$abs" | cut -c$(( 1 + ${#mp} ))-)"
          for n in $(echo "$sub" | tr '/' ' ') ; do
            test "$n" = "srv" && continue
            nl="$(echo "/srv/$n-$dvid-"*)"
            test -e "$nl" && continue || {
              # Stop on the last element, or warn
              test "$n" = "$name" && break || {
                warn "missing $nl for $n"
              }
            }
          done
        }

        # 3. Unless silent, warn if volume is not local, or exit in strict-mode
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
        # Update disk volume manifest, and reinitialize service links
        disk.sh check-all || {
          disk.sh update-all || {
            error "Failed updating volumes catalog and links"
          }
        }
      ;;

    * ) error "'$1'?" 1 ;;

  esac
}

# Check if any of 'lower-case' sid and Title-Case path of NAME in DIR exists
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



htd_man_1__count_files='Count files under dir(s)'
htd_spc__count_files='count-files DIR [DIR..]'
htd__count_files()
{
  for p in "$@"
  do
    test -d "$p" || {
      continue
    }
    note "$p: $(find $p -type f | wc -l)"
  done
}


htd_man_1__find_broken_symlinks='Find broken symlinks'
htd__find_broken_symlinks()
{
  find_broken_symlinks "$@"
}

htd_man_1__find_skip_broken_symlinks='Find except broken symlinks'
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


htd__reader_update()
{
  cd /Volumes/READER

  for remote in $(git remote)
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


htd_man_1__annex='Extra commands for GIT Annex.

  remote-export REMOTE [RSync-Options]
    Use given remote name as plain export, like annex v6.2 should (but using
    older annex). See import for rsync-options.

  remote-import REMOTE [RSync-Options]
    Use given remote name to get rsync info, sync data from remote dir to
    TMPDIR and call git annex import TMPDIR. Local dir should be the target
    repo. See import.

These commands use a specialremote, provided by GIT Annex. However the remote
should not be used for regular sync. See `configuring a special remote for tree
export`__.

.. __: https://git-annex.branchable.com/design/exporting_trees_to_special_remotes/#index1h2

  import RSync-Info Checkout-Dir [RSync-Options]
    Import from any rsync-spec, rsync first if not a local directory.
    Then call git annex import ... This passes extra arguments as options to
    rsync, e.g. to use include/exclude patterns. Also before git-annex-import
    all normal tracked files are copied from source.

  list
    List annex paths
  metadata
    Formfeed delineated k/v
'
htd__annex()
{
  test -n "$1" || error command 1
  test -n "$dry_run" || dry_run=true

  local srcinfo= rsync_flags=avzui act=$1 ; shift 1
  falseish "$dry_run" || rsync_flags=${rsync_flags}n

  get_srcinfo() # Get URL for remote name
  {
    srcinfo=$(git config --local --get remote.${remote}.annex-rsyncurl)
    test -n "$srcinfo" || {
        package_lib_set_local "."
        srcinfo=$(package_get_keys urls.${remote})
    }
    test -n "$srcinfo" || error "annex remote-export srcinfo ($remote)" 1
  }

  case "$act" in

    remote-export ) local remote=$1 ; shift
        test -d "./.git/annex" || error annex 1
        test -n "$remote" || error remote 1
        get_srcinfo
        rsync -${rsync_flags}L "./" "$srcinfo" "$@" || return $?
      ;;

    remote-import ) local remote=$1 ; shift
        test -d "./.git/annex" || error annex 1
        test -n "$remote" || error remote 1
        get_srcinfo
        htd__annex import $srcinfo/ . "$@" || return $?
      ;;

    import )
        # Add remote-dir import to git-annex-import, and do not turn
        # tracked files into annexed files
        test -n "$1" || error src 1
        test -n "$2" || error dest 1
        test -d "$2/.git/annex" || error annex-import 1

        local tmpd=$(base=htd-annex setup_tmpd) srcinfo=$1 dest=$2 ; shift 2
        # See if remote-spec is local path, or else sync. Extra arguments
        # are used as rsync options (to pass on include/exclude patterns)
        test -e "$srcinfo" && tmpd=$srcinfo ||
          rsync -${rsync_flags} "$srcinfo" "$tmpd" "$@"

        {
            cd "$dest" ;

            # Copy normal tracked files so annex doesn't import them
            htd__git_import "$tmpd" ||
                warn "git-import $tmpd returned $?" 1

            trueish "$dry_run" && {
              echo git annex import --deduplicate $tmpd/*

            } || {

              # Force is needed to take updates during import
              git annex import --force --deduplicate $tmpd/* ||
                  warn "annex-import $srcinfo returned $? ($tmpd)"

              git status || true
            }
        }
        # Remove tmpdir if not a local srcdir
        test -e "$srcinfo" && note "Leaving localdir $srcinfo" || rm -r $tmpd
      ;;

    metadata ) htd_annex_files "$@" | annex_metadata ;;

    git-deleted )
        git ls-files -d | while read -r fn;
        do echo "$(basename $(git show HEAD^:"$fn")) $fn" ; done
      ;;

    drop-git-deleted )
        git ls-files -d | while read -r fn;
        do echo "$(basename $(git show HEAD^:"$fn")) $fn" ; done |
          annex_dropkeys
      ;;

    * ) subcmd_prefs=${base}_annex_ try_subcmd_prefixes "$@" || return ;;

  esac
}

htd_run__annex_fsck=i
htd__annex_fsck()
{
  local rules=.sync-rules.list
  test -e "$rules" || {
    note "No local rules, executing global rules"
    rules=~/.conf/sync-rules.list
  }
  read_nix_style_file $rules | while read dir branch remotespec which
  do
    dir="$(htd prefixes expand "$dir")"

    { cd $dir ; test "$which" = "1" -o "$which" = "2" && {

        git annex fsck -q && {
            echo "$dir" >$passed
        } || {
            error "[$dir] fsck failure ($?)"
            echo "$dir" >$failed
        }
    } ; }
  done
  test -s "$passed" &&
      note "$(count_lines "$passed") repositories OK" || warn "Nothing to do"
}


htd_man_1__sync='Go over local or global repo paths for syncing'
htd__sync()
{
  local rules=.sync-rules.list
  test -e "$rules" || {
    test -e .git/annex && {
      git annex sync
      return $?
    }
    sys_confirm "No local rules, execute all global rules?" || return $?
    rules=~/.conf/sync-rules.list
  }
  read_nix_style_file $rules | while read dir branch remotespec which
  do
    dir="$(htd prefixes expand "$dir")"

    cd $dir || error "cd '$dir'" 1
    test "$remotespec" != "*" || remotespec="$(git remote | lines_to_words)"
    test -z "$(git status --porcelain -uno)" || {
      warn "Ignoring dirty index at '$dir'"
      continue
    }

    test "$branch" = "$(git rev-parse --abbrev-ref HEAD)" && {

        note "[$dir] updating '$branch' from '$remotespec'.."
    } || {
        note "[$dir] Checking out '$branch' for '$remotespec'.."
        git checkout -q $branch ||
            error "[$dir] git checkout '$branch' ($?)" 1
    }

    test -z "$which" -o "$which" = "0" -o "$which" = "2" && { # GIT

        for remote in $remotespec
        do
            test "$remote" = "$hostname" && continue
            git pull -q $remote $branch ||
                error "[$dir] git pull '$remote $branch' ($?)" 1
        done
        for remote in $remotespec
        do
            test "$remote" = "$hostname" && continue
            git push -q $remote $branch ||
                error "[$dir] git push '$remote $branch' ($?)" 1
            note "[$dir] $branch in sync with $remote/$branch"
        done

    }
    test "$which" = "1" -o "$which" = "2" && { # GIT-Annex

        note "[$dir] Backing up tracked local files.."
        git annex sync -q $remotespec ||
            error "[$dir] git annex sync '$remotespec' ($?)" 1

        for remote in $remotespec
        do
            test "$remote" = "$hostname" && continue
            trueish "$(git config --get remote.$remote.annex-ignore)" && continue
            git annex copy -q --to $remote ||
                error "[$dir] git annex copy --to '$remote' ($?)" 1
            note "[$dir] backup done at $remote"
        done
    }
    continue
  done
}


htd_man_1__annices='
'
htd__annices()
{
  case "$1" in

      #findbysha2list ) shift ;;
      #lookup-by-key ) shift ;;
      #lookup-by-sha2 ) shift ;;
      #scan-by-sha2 ) shift ;;

      * ) error "'$1'?" 1
        ;;
  esac
}


htd_man_1__init_backup_repo='Initialize local backup annex and symlinks'
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
      eval $act git annex copy --to 21-2
    }
    note "Backed up to /srv/backup-local"
  }
}
htd_pre__backup=htd_backup_prereq
htd_argsv__backup=htd_backup_argsv
htd_optsv__backup=htd_backup_optsv


htd_man_1__pack_create="Create archive for dir and add ck manifest"
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

htd_backup_argsv()
{
  test -n "$*" || error "Nothing to backup?" 1
  opt_args "$@"
}

htd_backup_optsv()
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
          main_options_v "$1"
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
    nodemon -x "./vendor/bin/behat $1" \
      --format=progress \
      -C $(htd__bdd_args)
  } || {
    set -- test/
    nodemon -x "./vendor/bin/behat $1" \
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
  lib_load src functions
  local functions=0 lines=0
  for src in $@
  do
    src_id=$(htd_prefix $src)
    $LOG file_warn $src_id "Listing info.." >&2
    $LOG header "Box Source" >&2
    functions_=$(functions_list "$src" | count_lines)
    functions=$(( $functions + $functions_ ))
    $LOG header2 "Functions" $functions_ >&2
    count=$(count_lines "$src")
    lines=$(( $lines + $count ))
    $LOG header3 "Lines" $count >&2
    $LOG file_ok $srC_id >&2
  done
  $LOG header2 "Total Functions" $functions >&2
  $LOG header3 "Total Lines" $lines >&2
  $LOG done $subcmd >&2
}


htd_man_1__functions='List functions, group, filter, and use `source` to get
source-code info.

   list-functions|list-func|ls-functions|ls-func
     List shell functions in files.
   find-functions Grep Scripts...
     List functions matching grep pattern in files
   list-groups [ Src-Files... ]
     List distinct values for "grp" attribute. See box-list-function-groups.
   list-attr [ Src-Files... ]
     See box-list-functions-attrs.

'
htd_run__functions=iAOl
htd__functions() { false; }
htd_libs__functions=htd-functions\ functions

htd_als__list_functions=functions\ list
htd_als__list_funcs=functions\ list
htd_als__ls_functions=functions\ list
htd_als__ls_funcs=functions\ list

htd_als__find_functions=functions\ find
htd_als__find_funcs=functions\ find

htd_als__funcs=functions


htd_man_1__find_function='Get function matching grep pattern from files
'
htd_spc__find_function='find-function <grep> <scripts>..'
htd__find_function()
{
  func=$(first_match=1 find_function "$@")
  test -n "$func" || return 1
  echo "$func"
}
htd_grp__find_function=box-src


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
      git show $version2:$name | list_functions_foreach |
        sed 's/\(\w*\)()/\1/' | sort -u > $tmplistprev
      test -n "$version1" && {
        note "Listing new fuctions at $version1 since $version2 in $name"
        git show $version1:$name | list_functions_foreach |
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


htd_man_1__vfs='
    mount NAME PATH CLASS
      Mount VFS
    umount NAME
      Unmount VFS
    mounted NAME
      Check for VFS name in mount list
    running NAME
      Check for VFS process ID
    check NAME
      Run mounted and running check.
'
htd_run__vfs=l
htd_libs__vfs=vfs
htd__vfs()
{
  # FIXME default vfs status test -n "$1" || set -- status
  verify=1 subcmd_prefs=${base}_vfs_ try_subcmd_prefixes "$@"
}


htd_run__hoststat=fl
htd_libs__hoststat=hoststat
htd__hoststat()
{
  test -n "$1" || set -- status
  subcmd_prefs=${base}_hoststat_ try_subcmd_prefixes "$@"
}


htd_run__volumestat=l
htd_libs__volumestat=volumestat
htd__volumestat()
{
  test -n "$1" || set -- status
  subcmd_prefs=${base}_volumestat_ try_subcmd_prefixes "$@"
}


htd__darwin()
{
  test -n "$1" || set -- list
  subcmd_prefs=${base}_darwin_\ darwin_ try_subcmd_prefixes "$@"
}
htd_run__darwin=f


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
  symlinks_id=${symlinks_id-script-mpe-symlinks}
  symlinks_attrs= symlinks_file=
'
htd__checkout()
{
  eval set -- $(lines_to_args "$arguments") # Remove options from args
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


htd__env='Print env var names (local or global)

  all | local | global | tmux
    List env+local, local, env or tmux vars.
    Names starting with "_" are filtered out.

  pathnames | paths | pathvars
    Tries to print names, values, or variable declarations where value is a
    lookup path. The values must match ``*/*:*/*``. This may include some URLs.
    Excludes values with only local names, or at least two paths.

  dirnames | dirs | dirvars
    Print names, values, or variable declarations where value is a directory path.

  filenames | files | filevars
    Print names, values, or variable declarations where value is a file path.

  symlinknames | symlinks | symlinkvars
    Print names, values, or variable declarations where value is a symlink path.

  foreach (all|local|global) [FUNC [FMT [OUT]]]
    Print <OUT>names, <OUT>s or <OUT>vars.
    By default prints where value is an existing path.

XXX: Doesnt print tmux env. and whatabout launchctl
'

htd__env()
{
  test -n "$1" || set -- all
  case "$1" in

    foreach )
        test -n "$4" -a -n "$5" || set -- "$1" "$2" "$3" vars
        test -n "$2" || set -- "$1" all "$3" "$4" "$5"
        test -n "$3" || {
            _f() { test -e "$2" ; }
            set -- "$1" "$2" "_f" "$4" "$5"
        }
        htd__env $2 | while read varname
        do
            V="${!varname}" ; $3 "$varname" "$V" || continue
            case "$4" in
                ${5}names ) echo "$varname" ;;
                ${5}s ) echo "$V" ;;
                ${5}vars ) echo "$varname=$V" ;;
            esac
        done
          ;;

    pathnames | paths | pathvars )
        _f(){ case "$2" in *[/]*":"*[/]* ) ;; * ) return 1 ;; esac; }
        htd__env foreach "$2" _f "$1" path
      ;;

    dirnames | dirs | dirvars )
        _f() { test -d "$2" ; }
        htd__env foreach "$2" _f "$1" dir
      ;;

    filenames | files | filevars )
        _f() { test -f "$2" ; }
        htd__env foreach "$2" _f "$1" file
      ;;

    symlinknames | symlinks | symlinkvars )
        _f() { test -L "$3" ; }
        htd__env foreach "$2" _f "$1" symlink
      ;;

    all )
        { env && local; } | sed 's/=.*$//' | grep -v '^_$' | sort -u
      ;;
    global )
        env | sed 's/=.*$//' | grep -v '^_$' | sort -u
      ;;
    local )
        local | sed 's/=.*$//' | grep -v '^_$' | sort -u
      ;;

    lookup-list ) shift ;
        lookup_path_list "$@"
      ;;

    lookup ) shift ;
        lookup_path "$@"
      ;;

    lookup-shadows ) shift ;
        lookup_path_shadows "$@"
      ;;

    #host ) # XXX: tmux, launch/system/init daemon?
    #  ;;
    tmux ) # XXX: cant resolve the from shell
        htx__tmux show local
      ;;
    #* ) # XXX: schemes looking at ENV, ENV_NAME
    #  ;;
  esac
}


# Show prefix of VIM install
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
          #${sudo}iptables -A INPUT -s ${ip} -j ACCEPT

          wlist=./allowed-ips.list
          wc -l $wlist
          read_nix_style_file $wlist |
          while read ip
          do
            ${sudo}iptables -A INPUT -s ${ip} -j ACCEPT
          done

          ${sudo}iptables -P INPUT DROP # Drop everything we don't accept
        ;;

      init-blist ) shift
          blist=./banned-ips.list
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

      -grep-auth-log-ips ) # get IP's to block from auth.log
          htd__ips -grep-auth-log |
            sed 's/.*from\ \([0-9\.]*\)\ .*/\1/g' |
            sort -u
        ;;

      -grep-auth-log ) # get IP's to block from auth.log
          ${sudo}grep \
              ':\ Failed\ password\ for [a-z0-9]*\ from [0-9\.]*\ port\ ' \
              /var/log/auth.log
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


htd__photos()
{
  PHOTOS_FOLDER=/Volumes/Zephyr/photos
  OSX_PHOTOS="/Volumes/Zephyr/Photos Library.photoslibrary"

  find "$OSX_PHOTOS/Thumbnails" -type f |
  while read thumb
  do
      grealpath --relative-to="$OSX_PHOTOS" "$thumb"
  done

  find "$OSX_PHOTOS/Masters" -type f |
  while read master
  do
      grealpath --relative-to="$OSX_PHOTOS" "$master"
  done
}


htd_man_1__ispyvenv='Check wether shell env has Python virtualenv, get prefix

Return 1 if false, or prints the virtualenv prefix. On env choice-interactive
prints a warning or notice to stderr as well.
'
htd__ispyvenv()
{
  python -c 'import sys
if not hasattr(sys, "real_prefix"): sys.exit(1)' && {
        trueish "$choice_interactive" && note "Running with Python virutalenv:"
        python -c 'import sys
print sys.prefix'
        return 0
    } || {
        trueish "$choice_interactive" && warn "No Python virtualenv set"
        return 1
    }
}
htd_als__pyvenv=ispyvenv
htd_als__venv=ispyvenv



htd_man_1__catalog='Build file manifests. See `htd help htd-catalog-*` for more
details per function.

Sets of catalogs

  [CATALOGS=.catalogs] list-local
    find catalog documents, cache full paths at CATALOG and list pathnames
  [CATALOG_DEFAULT=] name [DIR]
    select and set CATALOG filename from existing catalog.y*ml
  find
    for every catalog from "htd catalog list-local", look for literal string in it

Single catalogs

  [CATALOG=] list-files
    List file names or paths from catalog
  [CATALOG=] check
    Update cached status bits (see validate and fsck)
  [CATALOG=] status
    Run "check" and set return code according to status
  ck [CATALOG}
    print file checksums
  fsck [CATALOG]
    verify file checksums
  validate [CATALOG]
    verify catalog document schema
  doctree
    TODO doctree
  listtree
    List untracked files (not in SCM), or find with local ignores
  untracked
    List untracked files (not in SCM or ignored) not in catalog

Single catalog entry

  [CATALOG=] add [DIR|FILE]
    Add file, recording name, basic keys, and other file metadata.
    See also add-file, add-from-folder, add-all-larger,
  [CATALOG=] get-path NAME
    Get src-file (full path) for record
  [CATALOG=] drop NAME
    Remove record
  [CATALOG=] delete NAME
    Remove record and src-file
  drop-by-name [CATALOG] NAME
    See drop.
  copy NAME [DIR|CATALOG]
    Copy record and file to another catalog and relative src-path
  move NAME [DIR|CATALOG]
    Copy and drop record + delete file
  set [CATALOG] NAME KEY VALUE
    Add/set any string value for record.
  update [CATALOG] Entry-Id Value [Entry-Key]
    Update single key of signle entry in catalog JSON and write back.
  annex-import [Annex-Dir] [Annexed-Paths...]
    Update entries from Annex (backend key and/or metadata)

Functions without CATALOG argument will use the likenamed env. See
catalog-lib-load. Std. format is YAML.
'
htd__catalog()
{
  test -n "$1" || set -- status
  subcmd_prefs=${base}_catalog_ try_subcmd_prefixes "$@"
}
htd_run__catalog=f

htd_als__catalogs='catalog list'
htd_als__fsck_catalog='catalog fsck'


htd__annexdir()
{
  test -n "$1" || set -- status
  subcmd_prefs=annexdir_ try_subcmd_prefixes "$@"
}
htd_run__annexdir=f


# TODO move foreach to htd str
htd_man_1__foreach='Execute based on match for each argument or line

Executes "$act" and "$no_act" for each arg or line based on glob, regex, etc.
These can be function or command names that accept exactly one argument.
Without arguments (or "-") all input is read from standard-input.

This can be used to reuse a simple function that accepts one argument, into one
that accepts multiple arguments and/or reads from stdin and provides a way to
add filters. The defaults are "htd foreach * echo /dev/null -", but three
arguments are required. Ie. this simply echoes all lines on stdin:

  htd foreach "" "" ""

EXPR may be a glob, regex, command or function, or shell expression.
To prevent ambiguity, EXPR prefixes set the type ("g:", "r:", "x:" or "e:").
The default is glob, and no further effort is made ie. to detect existing
functions or commands. The signatures are:

  g:<glob>
  r:<regex>
     Test each arg/line S
  x:<callback>
     Invoke <callback> with each S as argument
  e:<shell-expression>
     Evaluate for each S, without any further arguments

For example scripts see `htd help filter`.
'
htd_spc__foreach='foreach EXPR ACT NO_ACT [ - | Subject... ]'
htd__foreach()
{
  local type_= expr_= act="$2" no_act="$3" s= p=
  foreach_match_setexpr "$@" ; shift 3
  foreach_match "$@"
}


htd_man_1__filter='Return matching paths from args or stdin

See `htd foreach` for EXPR and argument handling. Example to get "./*.lib.sh"
files:

   htd filter "*.lib.sh" *.sh
   htd filter "r:.*\.lib\.sh$" *.sh

These are just examples, instead of a new command some simple shell glob expansion
could give the same result. The real power of this routine is that it implements
the same wether input is arguments or lines on standard input, and can call
other functions to perform the actual testing. It is not restricted to testing
on filename/pathname only, and can work on any provided list directly.

List all executable or symlinks in tracked in GIT repository:

   git ls-files | htd filter e:"test -x \"./\$S\""
   git ls-files | htd filter x:"test -x"
   git ls-files | htd filter x:"test -h"

As another example emulate GNU `find` selectors based on file descriptor. Using
functions loaded by `htd`, similar actions are easier to write:

   git ls-files | htd filter-out x:"test -s" # find . -empty -type f
   git ls-files | htd filter "e:test \$(filesize \"./\$S\") -gt 1024" # +size
   git ls-files | htd filter "e:older_than \"\$S\" \$_1YEAR" # +time?

NOTE: that because the examples are single-quoted, it prevents any single quote
in the documentation. While it would make the above examples a bit more readable
with less escaping.
'
htd_spc__filter='filter EXPR [ - | PATH... ]'
htd__filter()
{
  local type_= expr_= mode_=
  foreach_match_setexpr "$1" ; shift
  mode_=1 htd_filter "$@"
}


htd_man_1__filter_out='Return non-matches for glob, regex or other expression

See `htd help filter`.
'
htd_spc__filter_out='filter EXPR [ - | PATH... ]'
htd__filter_out()
{
  local type_= expr_= mode_=
  foreach_match_setexpr "$1" ; shift
  mode_=0 htd_filter "$@"
}


htd_als__cal=calendar
htd__calendar()
{
  ncal -w
}


htd__whoami()
{
  note "Host: $(whoami) ($uname)"
  note "GIT: $(git config --get user.name)"
}


htd_man_1__watch='Alias to local script feature-watch [ARG]'
htd_als__watch='run feature-watch'


htd_man_1__resolve_modified='Helper to move files to GIT stage.

Each basename must test OK, then it is staged.
TODO: rewrite to infinite loop, that doesnt break until lst watch returns.
'
htd__resolve_modified()
{
  vc_modified | while read name
    do
      basename=$(filestripext "$name");
      mkid "$basename" "" "-_";
      note "$name: $basename: $id";
      echo "$id $name"
  done | join_lines - ' ' | while read component files
  do
    htd run test $component && git add $files
  done
}


htd_man_1__components='List component names, followed by associated paths

Default is run package-paths or read paths from stdin, and process basename
to Ids. Ie. components are based on pathnames, and are groups around a basename.
No sub-file components either.
'
htd__components()
{
  test -n "$package_components" && { eval $package_env || return $? ; }
  test -n "$package_components" || package_components=package_components
  test -n "$package_component_name" || package_component_name=package_component_name
  $package_components
}
htd_run__components=pq


htd_man_1__test_all='TODO: see htd run test-all for script.mpe, work towards
dynamic req/test spec?'
htd__test_all()
{
  htd__components | while read component files
  do
    htd run test $component
  done
}


htd_man_1__doc='Wrapper for documents modules (doc.lib and htd-doc.lib)

  list [Docstat-Glob]
  new [Title|Descr|Tags...]

See also docstat.lib
'
htd_run__doc=fpql
htd_libs__doc=doc\ htd-doc
htd__doc()
{
  test -n "$1" || set -- main-files
  doc_lib_init
  subcmd_prefs=${base}_doc_\ doc_ try_subcmd_prefixes "$@"
}
htd_als__docs=doc\ list


htd__dangling_blobs()
{
  git fsck | grep 'dangling blob' | cut -f 3 -d ' ' | while read sha1
  do
    echo $sha1
    #vc.sh list-objects $sha1
    #git show $sha1
  done
}


htd__pm2()
{
  test -n "$1" || set -- list
  subcmd_prefs=${base}_pm2_ try_subcmd_prefixes "$@"
}
htd_run__pm2=f


htd_man_1__make='
    files
    targets
'
htd__make()
{
  test -n "$1" || set -- status
  subcmd_prefs=${base}_make_ try_subcmd_prefixes "$@"
}
htd_run__make=f


htd_man_1__todo='
tasks
box, composure

help-commands is hard-coded and more documented but getting stale.
commands is a long, long listing is generated en-passant from the source
'


htd_man_1__composure='Composure: dont fear the Unix chainsaw

A set of 7 shell functions, to rule all the others:

cite KEYWORD.. - create keyword function
draft NAME [HIST] - create shell routine function of last command or history index
glossary - list all composure functions
metafor - retrieve string from typeset output
reference FUNC - print usage
revise FUNC - edit shell routine function
write FUNC.. - print composed function(s)

The benefit of using shell functions is free auto-complete without any fus.

Composure includes private functions under the "_" prefix. Its main techniques
are:

1. empty (no-op) functions for keeping strings (iso. vars or comments), for
   better performance having typeset access function bodies and metafor grep
2. draft/revise/write and other helper functions to create new functions,
   stored at ~/.local/composure/*.inc

reference accesses all the interesting metadata keywords for a function. The
short help string is called "about".

XXX: it would be interesting to "overload" functions, or rewrite compsure
entirely using composure functions. all the files need some organization,
have metadata for lib or cmd groups. ie. let it generate itself, or
customizations.

the interesting bit is overriding of functions. like when does a app decide
to use the global, host, vendor provided scripts or when does it let a local
user provided script take over.
'


htd_man_1__meta='

'$meta_api_man_1'

See also embyapi'
htd__meta()
{
  lib_load meta
  subcmd_prefs=meta_ try_subcmd_prefixes "$@"
}


htd_man_1__meta='
'$emby_api_man_1
htd__embyapi()
{
  lib_load meta
  upper=0 mkvid "$1" ; shift ;
  func_exists emby_api__$vid || error "$vid" 1
  emby_api_init
  emby_api__$vid "$@" || return $?
}


htd_man_1__src=''
htd_libs__src=htd-src
htd_run__src=fl
htd__src()
{
  test -n "$1" || set -- default
  subcmd_prefs=${base}_src_ try_subcmd_prefixes "$@"
}


htd_man_1__docstat='Build docstat index from local documents

    proc - Run processor for single document
    check - Check, update entry for single document
    update - Refresh entry for single document w/o check
    extdescr -  Update status descriptor bits of entry
    extitle -  Update title of entry
    extags - Update tags for entry
    ptags - Reset primary tag

    procall - Process all documents
    addall - Check index for all documents
    run - Run any other sub-command for each doc

    checkidx - Slow duplicate index check
    taglist - updat taglist from index
'
htd__docstat()
{
  test -n "$1" || set -- list
  doc_lib_init
  subcmd_prefs=docstat_ try_subcmd_prefixes "$@"
}
htd_run__docstat=ql
htd_libs__docstat=docstat\ ctx-doc\ doc


htd_man_1__context='
  TODO context list -
'
htd__context()
{
  test -n "$1" || set -- list
  subcmd_prefs=${base}_context_ try_subcmd_prefixes "$@"
}
htd_run__context=l
htd_libs__context=context\ htd-context
htd_als__ctx=context


htd_run__lists=q
htd__lists()
{
  htd__gtasks_lists
}


htd_man_1__urlstat='Build urlstat index

  list [Glob]
    List entries
  urllist ? [Stat-Tab]
    List URI-Refs, see htd urls for other URL listing cmds.
  entry-exists URI-Ref [Stat-Tab]
  check [--update] [--process]
    Add missing entries, update only if default stats changed. To update stat
    or other descriptor fields, or (re)process for new field values set option.
  checkall [-|URI-Refs]...
    Run check
  updateall
    See `htd checkall --update`
  processall
    See `htd checkall --process --update`
'
htd__urlstat()
{
  eval set -- $(lines_to_args "$arguments") # Remove options from args
  subcmd_default=list urlstat_check_update=$update \
      subcmd_prefs=urlstat_ try_subcmd_prefixes "$@"
}
htd_run__urlstat=qliAO
htd_libs__urlstat=urlstat


htd_man_1__scrtab='Build scrtab index

  new [NAME] [CMD]
    Create a new SCR-Id, if name is a file move it to the SCR dir (ignore CMD).
    If CMD is given for name, create SCR dir script. Else use as literal cmd.
  list [Glob]
    List entries
  scrlist ? [Stat-Tab]
    List SCR-Ids
  entry-exists SCR-Id [Stat-Tab]
  check [--update] [--process]
    Add missing entries, update only if default tabs changed. To update tab
    or other descriptor fields, or (re)process for new field values set option.
  checkall [-|SCR-Ids]...
    Run check
  updateall
    See `htd checkall --update`
  processall
    See `htd checkall --process --update`
'
htd__scrtab()
{
  eval set -- $(lines_to_args "$arguments") # Remove options from args
  subcmd_default=list subcmd_prefs=scrtab_\ htd_scrtab_ try_subcmd_prefixes "$@"
}
htd_run__scrtab=qliAO


htd_man_1__redo=''
htd__redo()
{
  subcmd_default=list subcmd_prefs=redo_ try_subcmd_prefixes "$@"
}
htd_run__redo=l


htd_man_1__stattab='Build stattab index

  new [NAME] [STAT]
    Create a new STAT-Id
  list [Glob]
    List entries
  check
    Add missing
  entry-exists STAT-Id
'
htd__sttab()
{
  eval set -- $(lines_to_args "$arguments") # Remove options from args
  subcmd_default=list subcmd_prefs=stattab_\ htd_stattab_ try_subcmd_prefixes "$@"
}
htd_run__sttab=qliAO
htd_libs__sttab=stattab


htd_man_1__project_stats=''
htd_spc__project_stats='project-stats [CMD ARGS..]'
htd__project_stats()
{
  project_stats_req || return
  eval set -- $(lines_to_args "$arguments") # Remove options from args
  subcmd_default=stat
  subcmd_prefs=${base}_project_stats_\ project_stats_ try_subcmd_prefixes "$@"
}
htd_run__project_stats=qilAO
htd_libs__project_stats=project-stats\ htd-project-stats
htd_argsv__project_stats=opt_args


htd_man_1__str=''
htd_spc__str='str [CMD ARGS..]'
htd__str()
{
  eval set -- $(lines_to_args "$arguments") # Remove options from args
  subcmd_prefs=${base}_str_\ str_ try_subcmd_prefixes "$@"
}
htd_run__str=ilAO
htd_libs__str=str\ htd-str
htd_argsv__str=opt_args

htd_als__count_words=str\ wordcount
htd_als__count_lines=str\ linecount
htd_als__count_columns=str\ colcount
htd_als__count_chars=str\ charcount


# -- htd box insert sentinel --



# Script main functions

htd_main()
{
  local scriptname=htd base=$(basename "$0" .sh) \
    scriptpath="$(cd "$(dirname "$0")"; pwd -P)" \
    upper= \
    package_id= package_cwd= package_env= \
    subcmd= subcmd_alias= subcmd_args_pre= \
    arguments= subcmd_prefs= options= \
    passed= skipped= error= failed=

  test -n "$verbosity" || local verbosity=5

  htd_init || exit $?
  case "$base" in

    $scriptname )

        # Default subcmd
        test -n "$1" || {
          test "$stdio_0_type" = "t" && {
            set -- main-doc-edit
          } || {
            set -- status
          }
        }

        main_init
        export stdio_0_type stdio_1_type stdio_2_type

        htd_lib "$@" || error htd-lib $?
        main_run_subcmd "$@" || r=$?
        htd_unload || r=$?

        # XXX: cleanup, run_subcommand with ingegrated modes?
        #  test -z "$arguments" -o ! -s "$arguments" || {

        #    info "Setting $(count_lines $arguments) args to '$subcmd' from IO"
        #    set -f; set -- $(cat $arguments | lines_to_words) ; set +f
        #  }
      ;;

    * )
        error "not a frontend for $base ($scriptname)" 1
      ;;

  esac
}

htd_init_etc()
{
  lst_init_etc
  #XXX: test ! -e .conf || echo .conf
  #test ! -e $UCONFDIR/htd || echo $UCONFDIR
}

# The default optionparser for htd, see htd-subcmd-optsv
htd_optsv()
{
  set -- $(lines_to_words $options)
  for opt in "$@"
  do
    case "$opt" in
      -S* ) search="$(echo "$opt" | cut -c3-)" ;;
      * ) define_all=1 main_options_v "$opt" ;;
    esac
  done
}

htd_init()
{
  # XXX test -n "$SCRIPTPATH" , does $0 in init.sh alway work?
  test -n "$scriptpath"
  local __load_lib=1
  export SCRIPTPATH=$scriptpath:$scriptpath/commands:$scriptpath/contexts
  . $scriptpath/util.sh || return $?
  lib_load os std sys sys-htd str stdio src main argv match vc
  . $scriptpath/tools/sh/box.env.sh
  box_run_sh_test
  lib_load htd vc web src
  lib_load box date
  case "$uname" in Darwin ) lib_load darwin ;; esac
  # -- htd box init sentinel --
}

htd_lib()
{
  local __load_lib=1
  . $scriptpath/match.sh
  lib_load list ignores table disk remote package htd-package htd-scripts \
      service archive prefix tmux schema ck net \
      catalog journal annex lfs pm2 make docstat du u-s htd-u-s
  # -- htd box lib sentinel --
}

# Use hyphen to ignore source exec in login shell
case "$0" in "" ) ;; "-"* ) ;; * )
  # Ignore 'load-ext' sub-command
  test "$1" != load-ext || __load_lib=1
  test -n "$__load_lib" || {
    htd_main "$@" || exit $?
  }
;; esac

# Id: script-mpe/0.0.4-dev htd.sh
