#!/bin/bash

#FIXME: !/bin/sh
#
# Htdocs: work in progress 'daily' shell scripts
#
htd_src=$_

set -o posix
set -e

version=0.0.4-dev # script-mpe


htd__inputs="arguments prefixes options"
htd__outputs="passed skipped error failed"

htd_load()
{
  # -- htd box load insert sentinel --

  # Default-Env upper-case: shell env constants
  local upper=1 title=

  default_env CWD "$(pwd)" || debug "Using CWD '$CWD'"
  not_trueish "$DEBUG" || {
    test "$CWD" = "$(pwd -P)" || warn "Current path seems to be aliased ($CWD)"
  }

  default_env EDITOR vim || debug "Using EDITOR '$EDITOR'"
  test -n "$TODOTXT_EDITOR" || {
    test -x "$(which todotxt-machine)" &&
      TODOTXT_EDITOR=todotxt-machine || TODOTXT_EDITOR=$EDITOR
  }
  test -n "$TASK_EXT" || TASK_EXT="ttxtm"
  test -n "$TASK_EXTS" || TASK_EXTS=".ttxtm .list .txt"

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
  test -e cabinet && {
    default_env Cabinet-Dir "$(pwd)/cabinet"
  } || {
    default_env Cabinet-Dir "$HTDIR/cabinet"
  }
  debug "Using Cabinet-Dir '$CABINET_DIR'"
  test -d "$HTD_TOOLSDIR/bin" || mkdir -p $HTD_TOOLSDIR/bin
  test -d "$HTD_TOOLSDIR/cellar" || mkdir -p $HTD_TOOLSDIR/cellar
  default_env Htd-BuildDir .build
  test -n "$HTD_BUILDDIR" || exit 121
  test -d "$HTD_BUILDDIR" || mkdir -p $HTD_BUILDDIR
  export B=$HTD_BUILDDIR

  # Set default env to differentiate tmux server sockets based on, this allows
  # distict CS env for tmux sessions
  default_env Htd-TMux-Env "hostname CS"
  # Initial session/window vars
  default_env Htd-TMux-Default-Session "Htd"
  default_env Htd-TMux-Default-Cmd "$SHELL"
  default_env Htd-TMux-Default-Window "$(basename $SHELL)"
  default_env Couch-URL "http://sandbox-3:5984"
  default_env GitVer-Attr ".version-attributes"
  default_env Ns-Name "bvberkum"

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
  go_to_dir_with .$scm && {
    # $localpath is the path from the project base-dir to the CWD
    localpath="$(normalize_relative "$go_to_before")"
    # Keep an absolute pathref for project dir too for libs not willing to
    # bother with or specify super-project refs, local name nuances etc.
    projdir="$(pwd -P)"
  } || {
    export localpath= projdir=
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
  test -n "$APP_ID" -o ! -e .app-id || read APP_ID < .app-id
  test -n "$APP_ID" -o ! -e "$GITVER_ATTR" ||
      APP_ID="$(get_property "$GITVER_ATTR" "App-Id")"
  test -n "$APP_ID" -o ! -e .git ||
      APP_ID="$(basename "$(git config remote.$vc_rt_def.url)" .git)"

  # TODO: go over above default-env and see about project-specific stuff e.g.
  # builddir and init parameters properly

  # Default locations for user-workspaces
  projectdirs="$(echo ~/project ~/work/*/)"

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

  # Shell template
  test -n "$pathnames" || pathnames=$UCONFDIR/pathnames.tab

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
  test -z "$flags" -o -z "$DEBUG" || stderr debug "Flags for '$subcmd': $flags"
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

    p ) # set package file and id, update.
        # Set to detected PACKMETA file, set main package-id, and verify var
        # caches are up to date. Don't load vars.
        # TODO: create var cache per package-id.
        pwd="$(pwd -P)"
        test -e "$PACKMETA" && {
            #|| error "No local package '$PACKMETA'" 1
            package_lib_set_local "$pwd" && update_package $pwd
            test -n "$package_id" && note "Found package '$package_id'"
        }
      ;;

    q )
        # Evaluate package env
        test -n "$PACKMETA_SH" -a -e "$PACKMETA_SH" && {
            . $PACKMETA_SH || error "No package Sh" 1
        } ||
            error "No local package" 1
      ;;

    r ) # register package - requires 'p' first. Sets PROJECT Id and manages
        # cache updates for subcommand data.

        # TODO: query/update stats?
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
  lst_init_ignores "" ignore
  #lst_init_ignores .names
  #match_load_table vars
}

# Set XSL-Ver if empty.
htd_load_xsl()
{
  test -z "$xsl_ver" && {
    test -x "$(which saxon)" && xsl_ver=2 || xsl_ver=1
  }
  test xsl_ver != 2 -o -x "$(which saxon)" ||
      error "Saxon required for XSLT 2.0" 1
  note "Set XSL proc version=$xsl_ver.0"
}



# Main aliases

#htd_als__install=install-tool
htd_als__update=update-checksums
htd_als__doctor=check

htd_man_1__check='Run diagnostics for CWD and system.

- Show tags for which list buffers exist
- Check file names
- Check file contents (fsck, cksum)

'
htd_run__check=pqi
htd_als__chk=check
htd__check()
{
  note "Starting 'check'..."

  test -n "$package_pd_meta_tasks_document" -a -n "$package_pd_meta_tasks_done" && {
    true # TODO ;)
    echo '---------'
    map=package_pd_meta_ package_sh tasks_document
    echo '---------'
    map=package_pd_meta_ package_sh tasks_document tasks_done
    echo '---------'

  } || stderr warning "Missing todo/done.txt env"

  map=package_pd_meta_ package_sh hub
  htd_tasks_load tasks-hub && {
      info "Looking for open contexts..."
      htd tasks-hub tagged
  }

  info "Looking for empty files..."
  subcmd=find-empty htd__find_empty \
      || stderr ok "No empty files" && stderr warnning "Empty files above"


  # Go over named paths, see if there are any checks for its contexts
  test -e "$ns_tab" && {

    info "Looking for contexts with 'checks' method..."
    fixed_table $ns_tab SID CONTECTS | while read vars
    do
      eval local "$vars"
      upper=1 mkvid "$SID"
      echo $vid

    done
  } || warn "No namespace table for $hostname"


  info "Prefix names"
  htd_prefix_names | while read prefix_name
  do
    base_path="$(eval echo \"\$$prefix_name\")"

    note "$prefix_name: $base_path"
  done

  # TODO: incorporate global/other projects and get glboal host picture
  # local dirs="Desktop Downloads bin .conf" ; foreach pd check
  #pd check && stderr ok "Projectdir checks out"

  # TODO check (some) names htd_name_precaution
  #htd check-names && stderr ok "Filenames look good"
  #htd__check_names

  # Check file integrity
  info "Checking file integrity"
  subcmd=fsck htd__fsck && stderr ok "File integrity check successful"
}


htd_man_1__fsck='Check file contents with locally found checksum manifests

Besides ck-validate and annex-fsck, look for local catalog.yml to validate too.
'
htd_run__fsck=i
htd__fsck()
{
  # Go over local cksum/filename table files
  ck_tab='*' htd__ck || return $?

  # Look for catalogdocs, go over any checksums there too
  ck_run_catalogs || return $?

  test -e .sync-rules.list && {

    # Use sync-rules to mark annex (sub)repos as fsck-enable/disable'd
    subcmd=annex-fsck htd__annex_fsck
  } || {

    # Look for and fsck local annex as last step
    vc_getscm || return 0
    vc_fsck || return
    test -d "$scmdir/annex" && {
        git annex fsck . || return
    } || true
  }
}
htd_als__file_check=fsck

htd_man_1__make='Go to HTDIR, make target arguments'
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
    # XXX: using compiled list of help ID since real list gets to long htd_usage
    echo ''
    echo 'Other commands: '
    other_cmds
    choice_global=1 std__help "$@"
  } || {
    echo_help $1 || {
      for func_id in "$1" "${base}__$1" "$base-$1"
      do
          htd_function_comment $func_id 2>/dev/null || continue
          htd_function_help $func_id 2>/dev/null && return 1
      done
      error "Got nothing on '$1'" 1
    }
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


htd__home()
{
  req_dir_env HTDIR
  echo $HTDIR
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


htd__expand()
{
  test -n "$1" || error "arguments expected" 1
  for x in $@
  do test -e "$x" && echo "$x"
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
  test -z "$search" || evoke="$evoke -c \"/$search\""

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


htd_man_1__edit_local="Edit an existing local file, or abort. "
htd_spc__edit_local="-e|edit <id>"
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
  $package_doc_find "$@"

  #doc_path_args
  #test -n "$1" || return $?

  #info "Searching files with matching name '$1' ($paths)"
  #doc_find_name "$1"

  #info "Searching matched content '$1' ($paths)"
  #doc_grep_content "\<$1\>"
}
htd_als___F=find-doc
htd_run__find_doc=x


htd_man_1__find_docs='Find documents

TODO: find doc-files, given local package metadata, rootdirs, and file-extensions
XXX: see doc-find-name
XXX: replace pwd basename strip with prefix compat routine
'
htd_spc__find_docs='find-docs [] [] [PROJECT]'
htd__find_docs()
{
  $package_docs_find "$@"
  #doc_find_name "$@"
}
#htd_run__find_docs=x


htd__volumes()
{
  test -n "$1" || set -- list
  case "$1" in
    list )
        htd__ls_volumes
      ;;
  esac
}


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


htd_man_1__status='Quick context status
'
htd_run__status=fSm
htd__status()
{
  test -n "$failed" || error "status: failed exists" 1

  local scm= scmdir=
  vc_getscm && {
    vc_status || {
      error "VC getscm/status returned $?"
    }
  } || { # not an checkout

    # Monitor paths
    # Using either lsof or update/access time filters with find we can list
    # files and other paths that a user has/has had in use.
    # There are plenty of use-cases based on this.

    # See htd open-paths for local paths, using lsof.
    # CWD's end up being recorded in prefixes. With these we can get a better
    # selection of files.

    # Which of those are projects
    note "Open-paths SCM status: "
    htd__current_cwd | while read p
    do verbosity=3
      { test -e "$p" && pd exists "$p"
      } || continue
      $LOG "header3" "$p" "$( cd "$p" && vc flags )" "" >&2
    done

    # Projects can still have a large amount of files
    # opened, or updated recently.

    # Create list of CWD, and show differences on subsequent calls
    #htd__open_paths_diff

    # FIXME: maybe something in status backend on open resource etc.
    #htd__recent_paths
    #htd__active

    stderr note "text-paths for main-docs: "
    # Check main documents, list topic elements
    {
      test ! -d "$JRNL_DIR" || EXT=$DOC_EXT htd__archive_path $JRNL_DIR
      htd__main_doc_paths "$1"
    } | while read tag path
    do
      test -e "$path" || continue
      htd tpath-raw "$path" || warn "tpath-raw '$path'..."
    done

  }

  # TODO:
  #  global, local services
  #  disks, annex
  #  project tests, todos
  #  src, tools

  # TODO: rewrite to htd proj/vol/..-status
  #( cd ; pd st ) || echo "home" >> $failed
  #( cd ~/project; pd st ) || echo "project" >> $failed
  #( cd /src; pd st ) || echo "src" >> $failed

  #htd git-remote stat

  test -s "$failed" -o -s "$errored" && stderr ok "htd stat OK" || true
}
htd_als__st=status
htd_als__stat=status


htd_man_1__status_cwd="Short status_cwd for current working directory"
htd_spc__status_cwd="status-cwd"
htd_run__status_cwd=fSm
htd__status_cwd()
{
  local pwd="$(pwd -P)" ppwd="$(pwd)" spwd=. scm= scmdir=
  vc_getscm && {
    cd "$(dirname "$scmdir")"
    vc_clean "$(vc_dir)"
  }

  stderr note "local-names: "
  # Check local names
  {
    htd check-names ||
      echo "htd:check-names" >>$failed
  } | tail -n 1
}


htd_als__update_stats=update-status
htd__update_status()
{
  # Go to project root
  cd "$workspace/$prefix"

  # Gather counts and sizes for SCM dir
  { test -n "$scm" || vc_getscm
  } && {

    htd_ws_stats_update scm "
$(vc_stats . "        ")" || return 1

    test -d "$workspace/$prefix/.$scm/annex" && {

        htd_ws_stats_update disk-usage "
              annex: $( disk_usage .$scm/annex)
              scm: $( disk_usage .$scm )
              (total): $( disk_usage )
              (date): $( date_microtime )" || return 1

      } || {

        htd_ws_stats_update disk-usage "
              scm: $( disk_usage .$scm )
              (total): $( disk_usage )
              (date): $( date_microtime )" || return 1
      }

  } || {

    htd_ws_stats_update disk-usage "
          (total): $( disk_usage )
          (date): $( date_microtime )" || return 1
  }

  # Use project metadata for getting more stats
  package_file "$workspace/$prefix" || return 0

  # TODO: Per project static code analysis
  #package_lib_set_local "."
  #. $PACKMETA_SH

  #for name in $package_pd_meta_stats
  #do
  #  echo $name: $( verbosity=0 htd run $name 2>/dev/null )
  #done
}

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
htd_man_1__context='TODO find packages, .meta dirs, DB client/query local-bg

    volume-status
    project-status
    workdir-status
'
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


htd_man_1__projects='Local project checkouts
  list
    TODO

  project-status
    See htd context
'
htd__projects()
{
  test -n "$1" || set -- info
  case "$1" in

    list ) shift
      ;;
  esac
}


htd_man_1__project='Project checkouts workingdirs

TODO: another level to checkout management, see projects

  releases
    List github releases
  sync
    ..
  update
    ..
  new
  exists
  scm
    TODO: init/update repo links
'
htd__project()
{
  test -n "$1" || set -- info
  test -e /srv/project-local || error "project-local missing" 1
  case "$1" in

    releases ) shift
          github-release info --user $NS_NAME --repo $APP_ID -j |
              jq -r '.Releases | to_entries[] as $k | $k.value.tag_name'
      ;;

    init ) shift
        # TODO: go from project Id, to namespace and provider
        #git@github.com:bvberkum/x-docker-hub-build-monitor.git
      ;;

    sync ) shift
      ;;
    update ) shift
      ;;

    new ) shift ; test -n "$1" || set -- "$(pwd)"
        htd__project exists "$1" && {
          warn "Project '$1' already exists"
        } || true

        ( cd "$1"
          htd__git_init_remote &&
          pd add . &&
          pd update . &&
          htd__git_init_version
        ) || return 1
      ;;

    exists ) shift ; test -n "$1" || set -- "$(pwd)"
        test -d "$1" || error "Project directory missing '$1'" 1
        local name="$(basename "$1")"
        test -e "/srv/project-local/$name" || {
          warn "Not a local project: '$name'"
          return 1
        }
      ;;

    scm ) shift ; test -n "$1" || set -- "$(pwd)"
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

    * ) error "? 'project $*'" 1
      ;;
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
            case "$machine_hw" in

                x86_64 ) BUILD_GOARCH="amd64" ;;
                * ) BUILD_GOARCH="$architecture" ;;
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
  script
'
htd_run__tools=f
htd_spc__tools="tools (<action> [<args>...])"
htd__tools()
{
  test -n "$1" || set -- list
  tools_json || return 1
  upper=0 mkvid "$1" ||
      error mkvid $?
  shift ; htd_tools_$vid "$@" || return $?
}
htd_grp__tools=htd-tools

# FIXME: htd_als__install="tools install"

htd_of__installed='yml'
htd_als__installed="tools installed"

htd_man_1__tools_outline='Transform tools.json into an outline compatible
format.
'
htd__tools_outline()
{
  rm $B/tools.json
  out_fmt=yml htd_tools_installed | jsotk update --pretty -Iyaml $B/tools.json -
  { cat <<EOM
{ "id": "$(htd_prefix "$(pwd -P)")/tools.yml",
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

htd_man_1__script="Get/list scripts in $HTD_TOOLSFILE. Statusdata is a mapping of
  scriptnames to script lines. See Htd run and run-names for package scripts. "
htd_spc__script="script"
htd_run__script=pSmr
htd_S__script=\$package_id
htd__script()
{
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
  test -n "$EXT" || EXT=.rst
  local pwd="$(normalize_relative "$go_to_before")" arg="$1"

  # Evaluate package env if local manifest is found
  test -n "$PACKMETA_SH" -a -e "$PACKMETA_SH" && {
    #. $PACKMETA_SH || error "Sourcing package Sh" 1
    eval local $(map=package_pd_meta_: package_sh log log_path log_title \
        log_entry log_path_ysep log_path_msep log_path_dsep) >/dev/null
  }

  test -n "$1" || {
    # If no argument given start looking for standard LOG file/dir path
    test -n "$log" && {
      # Default for local project
      set -- $log
    } || {
      # Default for Htdir
      set -- $JRNL_DIR/
    }
  }

  fnmatch "*/" "$1" && {
    test -e "$1" || error "unknown dir $1" 1
    jrnldir="$(strip_trail "$1")"
    shift
    set -- "$jrnldir" "$@"
  } || {
    # Look for here and in pwd, or create in pwd; if ext matches filename
    test -e "$1" || set -- "$pwd/$1"
    test -e "$1" || fnmatch "*$EXT" "$1"  && touch $1
    # Test in htdir with ext
    test -e "$1" || set -- "$arg$EXT"
    # Test in pwd with ext
    test -e "$1" || set -- "$pwd$1$EXT"
    # Create in pwd (with ext)
    test -e "$1" || touch $1
  }

  note "Editing $1"
  # Open of dir causes default formatted filename+header created
  test -d "$1" && {
    {
      # Prepare todays' day-links (including weekday and next/prev week)
      test -n "$log_path_ysep" || log_path_ysep="/"
      htd__today "$1" "$log_path_ysep" "$log_path_msep" "$log_path_dsep"
      # FIXME: need offset dates from file or table with values to initialize docs
      today=$(realpath "$1${log_path_ysep}today$EXT")
      test -s "$today" || {
        test -n "$log_title" || log_title="%A %G.%V"
        title="$(date_fmt "" "$log_title")"
        htd_rst_doc_create_update "$today" "$title" title created default-rst
      }
      # FIXME: bashism since {} is'nt Bourne Sh, but csh and derivatives..
      files=$(bash -c "echo $1${log_path_ysep}{today,tomorrow,yesterday}$EXT")
      # Prepare and edit, but only yesterday/todays/tomorrows' file
      #for file in $FILES
      #do
      #  test -s "$file" || {
      #    title="$(date_fmt "" '%A %G.%V')"
      #    htd_rst_doc_create_update "$file" "$title" title created default-rst
      #  }
      #done
      htd_edit_and_update $(realpath $files)
    } || {
      error "during edit of $1 ($?)" 1
    }

  } || {
    # Open of archive file cause day entry added
    {
      local date_fmt="%Y${log_path_msep}%m${log_path_dsep}%d"
      local today="$(date_fmt "" "$date_fmt")"
      grep -qF $today $1 || printf "$today\n  - \n\n" >> $1
      $EDITOR $1
      git add $1
    } || {
      error "err file $?" 1
    }
  }
}
htd_run__edit_today=p
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
htd_grp__archive_path=cabinet


# update yesterday, today and tomorrow and all current, prev and next weekday links
htd__today() # Jrnl-Dir YSep MSep DSep [ Tags... ]
{
  htd_jrnl_day_links "$@"
}
htd_grp__today=cabinet


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
htd_grp__edit_week=cabinet


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
htd_als__md=main-doc-edit
htd_als___E=main-doc-edit
htd_grp__main_doc_edit=cabinet



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
  test -n "$1" || set -- 12
  python -c "import os, base64;print base64.urlsafe_b64encode(os.urandom($1))"
}
htd_grp__random_str=box


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

  Commands in this group:

    htd tasks grep
        Run over the source, aggregating tagged comments as "task lines".
    htd tasks local
        Run the projects preferred way the aggregate tasks, if none given
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

  See tasks-hub for more local functions.

  Print package pd-meta tags setting using:

    htd package pd-meta tags
    htd package pd-meta tags-document
    htd package pd-meta tags-done
    .. etc,

  See also package.rst docs.
  The first two arguments TODO/DONE.TXT default to tags-document and tags-done.
'
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
htd_grp__tasks=tasks


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
htd_run__tasks_scan=ipqAO
htd_grp__tasks_scan=tasks


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
htd_run__tasks_grep=ipqAO
htd_grp__tasks_grep=tasks


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
htd_run__tasks_local=ipqAO
htd_grp__tasks_local=tasks


htd_man_1__tasks_edit='Invoke htd todotxt-edit for local package

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
  info "2.1. Env: $(var2tags \
    id todo_slug todo_document todo_done tags buffers add_files locks colw)"
  htd__tasks_session_start "$todo_document" "$todo_done" "$@"
  info "2.2. Env: $(var2tags \
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
  info "2.6. Env: $(var2tags \
    id todo_slug todo_document todo_done tags buffers add_files locks colw)"
  trueish "$remigrate" && htd_remigrate_tasks "$todo_document" "$todo_done" "$@"
  # XXX: where does @Dev +script-mpe go, split up? refer principle tickets?
  htd__tasks_session_end "$todo_document" "$todo_done"
}
htd_run__tasks_edit=epqA
htd_argsv__tasks_edit=htd_argsv__tasks_session_start
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
    htd tasks-hub
'
htd_man_1__tasks_hub_tags='List tags for which buffers exist'
htd_env__tasks_hub='projects=${projects-1} contexts=${contexts-1}'
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
htd_run__tasks_hub=epiAO
htd_grp__tasks_hub=tasks


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
htd_grp__tasks_process=tasks


# Given a list of tags, turn these into task storage backends. One path
# for reserved read/write access per context or project. See tasks.rst for
# the implemented mappings. Htd can migrate tasks between stores based on
# tag, or request new or remove existing tag Ids.
htd_man_1__tasks_buffers="For given tags, print buffer paths. "
htd_spc__tasks_buffers='tasks-buffers [ @Contexts... +Projects... ]'
htd__tasks_buffers()
{
  local dir=to/
  for tag in "$@"
  do
    case "$tag" in
      @be.* ) be=$(echo $tag | cut -c5- )
          echo to/be-$be.sh
        ;;
      +* ) prj=$(echo $tag | cut -c2- )
          echo to/do-in-$prj.list
          echo cabinet/done-in-$prj.list
          echo to/do-in-$prj.list
          echo cabinet/done-in-$prj.list
          echo to/do-in-$prj.sh
        ;;
      @* ) ctx=$(echo $tag | cut -c2- )
          echo to/do-at-$ctx.list
          echo cabinet/done-at-$ctx.list
          echo to/do-at-$ctx.list
          echo cabinet/done-at-$ctx.list
          echo to/do-at-$ctx.sh
          echo store/at-$ctx.sh
          echo store/at-$ctx.yml
          echo store/at-$ctx.yaml
        ;;
      '*' )
          echo \
              to/do-in-*.list \
              to/do-in-*.sh \
              to/do-at-*.list \
              to/do-at-*.sh \
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
htd_grp__tasks_buffers=tasks


htd_man_1__tasks_tags="Show tags for files. Files do not need to exist, but the
First two files will be created. "
htd_spc__tasks_tags='tasks-tags [todo] [done] [file..]'
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
htd_run__tasks_tags=pqi
htd_grp__tasks_tags=tasks


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
  tags="$(htd__todotxt_tags "$1" "$2" | lines_to_words ) $tags"
  note "Session-Start Tags: ($(echo "$tags" | count_words
    )) $(echo "$tags" )"
  info "3.2. Env: $(var2tags \
    id todo_slug todo_document todo_done tags buffers add_files locks colw)"
  # Get additional paths to all files, look for todo/done buffer files per tag
  buffers="$(htd__tasks_buffers $tags )"
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
htd_run__tasks_session_start=epqiA
htd_argsv__tasks_session_start()
{
  htd_tasks_load
  info "1.1. Env: $(var2tags \
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
  info "1.2. Env: $(var2tags \
      id todo_slug todo_document todo_done tags buffers add_files locks colw)"
}
htd_grp__tasks_session_start=tasks

htd__tasks_session_end()
{
  info "6.1 Env: $(var2tags \
      id todo_slug todo_document todo_done tags buffers add_files locks colw)"
  # clean empty buffers
  for f in $buffers
  do test -s "$f" -o ! -e "$f" || rm "$f"; done
  info "Cleaned empty buffers"
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
htd_grp__tasks_session_end=tasks


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


# Load from pd-meta.tasks.{document,done} [ todo_slug todo-document todo-done ]
htd_tasks_load()
{
  test -n "$1" || set -- init
  while test -n "$1" ; do case "$1" in

    init )
  eval $(map=package_pd_meta_tasks_:todo_ package_sh document done slug )
  test -n "$todo_document" || todo_document=todo.$TASK_EXT
  test -n "$todo_done" ||
    todo_done=$(pathname "$todo_document" $TASK_EXTS)-done.$TASK_EXT
  assert_files $todo_document $todo_done
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
  test -n "$tasks_hub" || {
    eval $(map=package_pd_meta_ package_sh tasks_hub)
  }
  test -n "$tasks_hub" || {
    test -e "./to" && tasks_hub=./to
  }
  test -n "$tasks_hub" || { error "No tasks-hub env" ; return 1 ; }
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

  todo is an alias for tasks-edit, see help there.

Other commands:

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


htd_man_1__git='FIXME: cleanup below

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

See also:

    htd vcflow
    vc
'

htd__git_remote_list_for_ns()
{
  grep -l NS_NAME=$1 $UCONFDIR/git/remote-dirs/*.sh
}

htd_man_1__git_remote='List repos at remote (for SSH), or echo remote URL.

If the argument represents a generic name for a remote account then a file
exists in ~/.conf/git/git-remote/*.sh with the properties. Else, the argument
represents one vendor-id or ns-name.

XXX: Action is optional sometimes
'
htd_spc__git_remote='git-remote [ Action ] [ Remote-Id | ( Vendor-Id [ Remote-Id ] [ Ns-Name ] ) ]'
htd__git_remote()
{
  local remote_dir= remote_hostinfo= remote_name=
  # Default is to list names at Htd-GIT-Remote env
  test -n "$*" || set -- "$HTD_GIT_REMOTE"
  # Insert empty arg if first represents remote-dir sh-props file
  test -e $UCONFDIR/git/remote-dirs/$1.sh && set -- "" "$@"

  # Default command to 'list' when remote-id exists and no further args given
  test -e $UCONFDIR/git/remote-dirs/$2.sh -a -z "$1" && {
    test -z "$3" && set -- "list" "$2" || set -- url "$2" "$3"
  }

  note "Args initialized '$*'"
  {
    C=$UCONFDIR/git/remote-dirs/$2.sh

    test -e "$C" || { local vendor=

        # See for specific account per vendor
        htd__git_remote_list_for_ns $2 | while read remote
        do
          test -h "$remote" && continue # ignore account aliases
          get_property $remote VENDOR
          vendor=$(get_property $remote VENDOR) || continue
          test -n "$vendor" || continue
          #set -- "$1" "$2" "$(basename $remote .sh)" "$vendor"
          stderr ok "account $2 for vendor $4 at file $3"

        done

        # FIXME
            stderr fail "account $2 for vendor $4 at file $3"
        test -n "$4" -a -n "$3" &&
            stderr ok "account $2 for vendor $4 at $3" ||
            error "Missing any remote-dir file for ns-name '$2'" 1
        C=$UCONFDIR/git/remote-dirs/$3.sh
        #set -- "$1" "$(basename $C .sh)" "$vendor" "$NS_NAME"
    }

    . $C

    test -n "$3" || {

        test -n "$vendor" || error "Vendor for remote now required" 1
        test -n "$NS_NAME" || error "Expected NS_NAME still.. really" 1
        #set -- "$1" "$(basename $C .sh)" "$vendor" "$NS_NAME"
    }

    #|| error "Missing remote GIT dir script" 1
    test -n "$remote_dir" || {
      info "Using $NS_NAME for $2 remote vendor path"
       remote_dir=$NS_NAME
    }

    note "Cmd initialized '$*'"
    case "$1" in

      stat )
          for rt in github dotmpe wtwta-1
          do
            repos=$UCONFDIR/git/remote-dirs/$rt.list
            { test -e $repos && newer_than $repos $_1DAY
            } || htd git-remote list $rt > $repos
            note "$rt: $(count_lines "$repos")"
          done
        ;;

      url )
          test -n "$3" || error "repo name expected" 1
          #git_url="ssh://$remote_host/~$remote_user/$remote_dir/$1.git"
          echo "$remote_hostinfo:$remote_dir/$3"
        ;;

      github-list )
          test -n "$2" || error "vendor-name required" 1
          test -n "$3" || error "remote-name required" 1
          test -n "$4" || error "ns-name required" 1
          test -n "$remote_list" || remote_list=$3.list
          confd=$UCONFDIR/git/remote-dirs
          repos=$UCONFDIR/git/remote-dirs/$3.json

          { test -e $repos && newer_than $repos $_1DAY
          } && stderr ok "File UCONF:git/remote-dirs/$3.json" || {

            URL="https://api.github.com/users/$4/repos"
            per_page=100
            htd_resolve_paged_json $URL per_page page > $repos || return $?
          }

          test -e $confd/$remote_list -a $confd/$remote_list -nt $repos && {

            cat $confd/$remote_list || return $?
          } || {
            jq -r 'to_entries[] as $r | $r.value.full_name' $repos | tee $confd/$remote_list
          }
          wc -l $confd/$remote_list
        ;;

      list ) test -z "$3" || error "no filter '$3'" 1
          # List values for first arguments
          test -n "$remote_list" && {

            htd__git_remote list $remote_list $NS_NAME || return $?

          } || {

            test -n "$remote_dir" && {
              ssh_cmd="cd $remote_dir && ls | grep '.*.git$' | sed 's/\.git$//g' "
              ssh $ssh_opts $remote_hostinfo "$ssh_cmd"
            } ||
               error "No SSH or list API for GIT remote '$1'" 1
          }
        ;;

      info )
          test -n "$2" || error "remote name required" 1
          test -n "$3" && {
            echo "remote.$2.git.url=$remote_hostinfo:$remote_dir/$3"
            echo "remote.$2.scp.url=$remote_hostinfo:$remote_dir/$3.git"
            echo "remote.$2.repo.dir=$remote_dir/$3.git"
            echo "remote.$2.hostinfo=$remote_hostinfo"
          } || {
            echo "remote.$2.repo.dir=$remote_dir"
            echo "remote.$2.hostinfo=$remote_hostinfo"
          }
        ;;

      sh-env ) shift
          test -n "$3" || set -- "$1" "$2" remote_
          htd__git_remote info "$1" "$2" | sh_properties - 'remote\.'"$1"'\.' "$3"
        ;;

      * ) error "'$1'?" 1 ;;

    esac
  }
}

htd__git_init_local() # [ Repo ]
{
  local remote=local
  repo="$(basename "$(pwd)")"
  [ -n "$repo" ] || error "Missing project ID" 1

  BARE=/srv/git-local/$NS_NAME/$repo.git
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
  htd__git_init_local

  # Remote repo, idem ditto
  local $(htd__git_remote sh-env "$remote" "$repo")
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
  htd__git_remote | grep $repo || {
    error "No such remote repo $repo" 1
  }
  source_git_remote
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
htd_defargs_repo__git_files=/srv/git-local/bvberkum/*.git


#
htd_man_1__git_grep='Run git-grep for every given repository, passing arguments
to git-grep.

With `-C` interprets argument as shell command first, and passes ouput as
argument(s) to `git grep`. Defaults to `git rev-list --all` output (which is no
pre-run but per exec. repo). If env `repos` is provided it is used iso. stdin.
Or if `dir` is provided, each "*.git" path beneath that is used. Else uses the
arguments. If stdin is attach to the terminal, `dir=/src` is set. Without any
arguments it defaults to scanning all repos for "git.grep".

TODO: spec is a work in progress.

'
htd_spc__git_grep='git-grep [ -C=REPO-CMD ] [ RX | --grep= ] [ GREP-ARGS | --grep-args= ] [ --dir=DIR | REPOS... ] '
htd_run__git_grep=iAO
htd__git_grep()
{
  set -- $(cat $arguments)
  test -n "$grep" || { test -n "$1" && { grep="$1"; shift; } || grep=git.grep; }
  test -n "$grep_args" -o -n "$grep_eval" && {
    note "Using env args:'$grep_args' eval:'$grep_eval'"
  } || {
    trueish "$C" && {
      test -n "$1" && {
        grep_eval="$1"; shift; } ||
          grep_eval='$(git rev-list --all)';
    } || {
      test -n "$1" && { grep_args="$1"; shift; } || grep_args=master
    }
  }

  test "f" = "$stdio_0_type" -o -n "$repos" -o -n "$1" ||
      dir=/srv/git-local/bvberkum

  note "Running ($(var2tags grep C grep_eval grep_args repos dir stdio_0_type))"
  htd_x__git_grep "$@" | { while read repo
    do
      {
        info "$repo:"
        cd $repo || continue
        test -n "$grep_eval" && {
          eval git --no-pager grep -il $grep $grep_eval || { r=$?
            test $r -eq 1 && continue
            warn "Failure in $repo ($r)"
          }
        } || {
          git --no-pager grep -il $grep $grep_args || { r=$?
            test $r -eq 1 && continue
            warn "Failure in $repo ($r)"
          }
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
    echo $repos | words_to_lines
  } ||
    { test -n "$dir" && {
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


htd_man_1__file='TODO: Look for name and content at path; then store and cleanup.

    newer-than
    older-than
    mediatype|mtype
    modified|mtime
    mtime-relative
    status
    info

Given path, find matching from storage using name, or content. On match, compare
and remove path if in sync.
'
htd__file()
{
  test -n "$1" || set -- info

  case "$1" in

      newer-than ) shift
          test -e "$1" || error "htd file new-than file expected '$1'" 1
          case "$2" in *[0-9] ) ;;
              * ) set -- "$1" "$(eval echo \"\$_$2\")" ;; esac
          newer_than "$1" "$2" || return $?
        ;;

      older-than ) shift
          test -e "$1" || error "htd file new-than file expected '$1'" 1
          case "$2" in *[0-9] ) ;;
              * ) set -- "$1" "$(eval echo \"\$_$2\")" ;; esac
          older_than "$1" "$2" || return $?
        ;;

      mediatype|mtype ) filemtype "$2" ;;

      modified|mtime ) filemtime "$2" ;;
      mtime-relative ) fmtdate_relative "$(filemtime "$2")" ;;

      size ) shift
          filesize "$1"
        ;;

      status ) shift
          # Search for by name
          echo TODO track htd__find "$localpath"

          # Search for by other lookup
          echo TODO track htd__content "$localpath"
        ;;

      info ) shift
          file -s "$2"
        ;;
      * ) error "'$1'?" 1
        ;;
  esac
}

htd__date()
{
  fmtdate_relative "$1"
}

htd__content()
{
  note "TODO: go over some ordered CONTENTPATH to look for local names.."
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


htd_man_1__vcflow='
TODO: see also vc gitflow
'
htd_run__vcflow=f
htd__vcflow()
{
  vcflow_lib_set_local
  test -n "$1" || set -- status
  upper=0 mkvid "$1" ; shift
  htd_vcflow_$vid "$@" || return $?
}
htd_als__gitflow_check_doc=vcflow\ check-doc
htd_als__gitflow_check=vcflow\ check
htd_als__gitflow=vcflow\ status


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

    expand-source-line ) fail TODO ;;

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
    sync-func(tion)|diff-func(tion) FILE1 FUNC1 DIR[FILE2 [FUNC2]]
    sync-functions|diff-functions FILE FILE|DIR
    diff-sh-lib [DIR=$scriptpath]
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

    help ) shift ; local file= grep_line=
        htd_function_comment "$@"
        htd_function_help
      ;;

    comment ) shift
        test -n "$1" || error "name or string-id expected" 1
        htd_function_comment "$@"
      ;;

    copy-paste ) shift

        test -f "$2" -a -n "$1" -a -z "$3" || error "usage: FUNC FILE" 1
        copy_paste_function "$1" "$2"
        note "Moved function $1 to $cp"
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

  # Extract both functions to separate file, and source at original scriptline
  cp_board= copy_paste_function "$2" "$1" || { r=$?
    error "copy-paste-function 1 ($r)"
    return $r
  }
  test -s "$cp" || error "copy-paste file '$cp' for '$1:$2' missing" 1
  src1_line=$start_line ; start_line= ; src1=$cp ; cp=
  cp_board= copy_paste_function "$4" "$3" || { r=$?
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
      diff $src1 $src2
      stderr ok "'$2'"
    }
  }
  trueish "$quiet" || {
    diff -bqr $src1 $src2 >/dev/null 2>&1 &&
    stderr debug "synced '$*'" ||
    stderr warn "not in sync '$*'"
  }

  # Move functions back to scriptline
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
htd_als__sync_func=sync-function


htd_man_1__diff_functions="List all functions in FILE, and compare with FILE|DIR

See diff-function for behaviour.
"
htd__diff_functions()
{
  test -n "$1" || error "diff-functions FILE FILE|DIR" 1
  test -n "$2" || set -- "$1" $scriptpath
  test -e "$2" || error "Directory or file to compare to expected '$2'" 1
  test -f "$2" || set -- "$1" "$2/$1"
  test -e "$2" || { info "No remote side for '$1'"; return 1; }
  test -z "$3" || error "surplus arguments: '$3'" 1
  htd__list_functions $1 |
        sed 's/\(\w*\)()/\1/' | sort -u | while read func
  do
    grep -bqr "^$func()" $1 || {
      warn "No function $func in $2"
      continue
    }
    htd__diff_function "$1" "$func" $2 || warn "Error on $1 $func $2 ($?)"
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
  See diff-functions for options'
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


htd_man_1__update='Checkout/update GIT version for this $scriptpath

Without argument, pulls the currently checked out branch. With env `push` turned
on, it completes syncing with the remote by returning the branch with a push.

If "all" is given as remote, it expands to all remote names.
'
htd_env__update='push'
htd_spc__update='update [<commit-ish> [<remote>...]]'
htd__update()
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
        trueish $push && git push "$remote" "$branch" || noop
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


htd_man_1__archive='Move path to archive path in htdocs cabinet

    <refs>...  =>  [<cabinet-dir>]/[<datepath>]/[<id>...]

See also backup, archive-path
'
htd_spc__archive='archive REFS..'
htd__archive()
{
  test -d "$CABINET_DIR" || error "Cabinet required <$CABINET_DIR>" 1
  test -n "$1" || warn "expected references to backup" 1
  while test $# -gt 0
  do
    test -d "$1" -o -f "$1" || continue
    mkdir -p $CABINET_DIR/$(date +%Y/%m/%d)/
    test -f "$1" && {
      mv $1 $CABINET_DIR/$(date +%Y/%m/%d)/$1$EXT
    } || {
      mv $1 $CABINET_DIR/$(date +%Y/%m/%d)/$1
    }
    shift
  done
}
htd_grp__archive=cabinet
htd_run__archive=iAO
htd_argsv__archive()
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
     Regenerated main.json and package.sh files (from YAML)
  package remotes-init
     Take all repository names/urls directly from YAML, and create remotes or
     update URL for same in local repository. The remote name and exact
     remote-url is determined with htd-repository-url (htd.lib.sh).
  package urls
     TODO: List URLs for package.
  package openurl|open-url [URL]

  package debug
     Log each Sh package settings.

  package dir-get-key <Dir> <Package-Id> [<Property>...]

Plumbing commands dealing with the local project package file. See package.rst.
These do not auto-update intermediate artefacts, or load a specific package-id
into env.
'
htd_run__package=iAO
htd__package()
{
  test -n "$1" || set -- debug
  upper=0 mkvid "$1" ; shift ; func=htd_package_$vid
  func_exists "$func" || func=package_$vid
  $func "$@" || return $?
}

htd_man_1__ls="List local package names"
htd_als__ls=package\ list-ids

htd_man_1__openurl="Open local package URL"
htd_als__openurl=package\ open-url



htd_man_1__topics='List topics'
htd__topics()
{
  test -n "$1" || set -- list
  upper=0 mkvid "$1" ; shift ; func=htd_topics_$vid
  lib_load topics
  func_exists "$func" || func=topics_$vid
  $func "$@" || return $?
}
htd_run__topics=iAOpx

htd_man_1__list_topics='List topics'
htd_als__list_topics="topics list"


htd_man_1__scripts='

  scripts names [GLOB]
    List local package script names, optionally filter by glob.
  scripts list [GLOB]
    List local package script lines for names
  scripts run NAME
    Run scripts from package

'
htd_run__scripts=pf
htd__scripts()
{
  test -n "$1" || set -- names
  upper=0 mkvid "$1"
  shift ; htd_scripts_$vid "$@" || return $?
}


htd_man_1__run='Run script from local package.y*ml

See list-run. TODO: alias to scripts
'
htd_spc__run='run [SCRIPT-ID [ARGS...]]'
htd__run()
{
  jsotk.py -sq path --is-new $PACKMETA_JS_MAIN scripts/$1 &&
      error "No script '$1'" 1

  # Evaluate package env
  test -n "$PACKMETA_SH" -a -e "$PACKMETA_SH" ||
      error "No local package" 1
  . $PACKMETA_SH || error "Sourcing package Sh" 1

  # List scriptnames when no args given
  test -z "$1" && {
    note "Listing local script IDs:"
    htd__scripts names
    return 1
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
      info "Starting '$run_scriptname' ($(pwd)) '$*'"
      eval $package_env
    }

    info "Starting '$run_scriptname' ($(pwd)) '$*'"

    package_sh_script "$run_scriptname" | while read scriptline
    do
      export ln=$(( $ln + 1 ))

      # Header or verbose output
      not_trueish "$verbose_no_exec" && {
        info "Scriptline: '$scriptline'"
      } || {
        printf -- "\t$scriptline\n"
        continue
      }

      # Execute
      (
        eval $scriptline

      ) && continue || { r=$?
          echo "$run_scriptname:$ln: '$scriptline'" >> $failed
          error "At line $ln '$scriptline' for '$run_scriptname' '$*' ($r)" $r
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
    htd__scripts list "$@"
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
    test "$out_fmt" = "json" && { echo "]" ; } || noop
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
htd_run__storage=Ap
htd_argsv__storage=htd_argsv__tasks_session_start
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
htd_grp__process=rules


htd_man_1__process='Process each item in list.
  name.list
  to/see.list
  @Task
  +proj:id.path
  @be.path
'
htd_spc__process='process [ LIST [ TAG.. [ --add ] | --any ]'
htd_env__process='
  todo_slug=${todo_slug} todo_document=${todo_document} todo_done=${todo_done}
'
htd__process()
{
  tags="$(htd__tasks_tags "$@" | lines_to_words ) $tags"
  note "Process Tags: '$tags'"
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
htd_run__process=epqA
htd_argsv__process=htd_argsv__tasks_session_start
htd_als__proc=process
htd_grp__process=proc


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
htd_grp__name_tags_all=meta


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
htd_grp__update_checksums=meta


# Checksums frontend


htd_man_1__ck='Validate given table-ext, ck-files, or default table.$ck-exts set

Arguments are files with checksums to validate, or basenames and extensions to
check. With no file given, checks table.*
'
htd_spc__ck='ck [ TAB | CK ]...'
htd__ck()
{
  local exts=
  for a in "$@" ; do
    test -e "$a" && continue
    exts="$exts $a"
  done

  #test -n "$1" || set -- main
  #while test $# -gt 0
  #do
  #  test -e "$1" || { shift; continue; }

    #local ck_ext=$(filenamext "$1") ck_tab="$(basename "$1" .$ck_ext)"

    for tab in $(ck_files "." $exts)
    do
      test -e "$tab" || continue
      ck_run $tab || return $?
    done
  #  shift
  #done
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
current environment.

Untmux is running with an environment matching the current, attach. Different
tmux environments are managed by using seperate sockets per session.

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

    * ) upper=0 mkvid "$1"; shift ; htd_tmux_$vid "$@" || return ;;
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



htd_man_1__disk='Enumerate disks
'
htd__disk()
{
  case "$uname" in

    Darwin )
        case "$1" in

          -info ) shift
               darwin_disk_info
            ;;

          -stats ) shift
               darwin_mount_stats
            ;;

          -partitions ) shift
            ;;

          -mounts ) shift
              darwin_mounts | cut -d ' ' -f 1
            ;;

          -bsd-mounts ) shift
               darwin_profile_xml "SPStorageDataType"
               #darwin_bsd_mounts
            ;;

          -partition-table ) shift
               darwin_mounts
            ;;

        esac
      ;;

    Linux ) htd__disk_proc "$@" ;;

    * ) error "Unhandled OS '$uname'" 1
      ;;
  esac
}

htd__disk_proc()
{
  test -e /proc || error "/proc/* required" 1
  case "$1" in

    check ) shift
        sudo blkid /dev/sd* | tr -d ':' | while read dev props
        do
          eval $props
          test -z "$PARTUUID" && {
            echo $dev no-PARTUUID
          } || {
            grep -sr "$PARTUUID" ~/htdocs/sysadmin/disks.rst || {
              echo $dev $PARTUUID
            }
            continue
          }
          test -n "$UUID" || {
            echo $dev no-UUID
            continue
          }
          grep -sr "$UUID" ~/htdocs/sysadmin/disks.rst && continue || {
            echo $dev $UUID
          }
        done
      ;;

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
           disk_list | while read dev
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

htd_man_1__tpaths='List topic paths (nested dl terms) in document paths
'
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
    path= rel_leaf= root= xml="$(htd__getxl "$1")"

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


htd_load__tpath_raw="xsl"
htd__tpath_raw()
{
  test -n "$1" || error "document expected" 1
  test -e "$1" || error "no such document '$1'" 1
  test -n "$xsl_ver" || xsl_ver=1
  info "xsl_ver=$xsl_ver"
  local xml="$(htd__getxl "$1")"

  case "$xsl_ver" in
    1 ) htd__xproc "$xml" $scriptpath/rst-terms2path.xsl ;;
    2 ) htd__xproc2 "$xml" $scriptpath/rst-terms2path-2.xsl ;;
    * ) error "xsl-ver '$xsl_ver'" 1 ;;
  esac
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

      saxon - $1 <<EOM
$2
EOM
    } || {
      test -e "$1" || error "no file for saxon: '$1'" 1
      saxon $1 $2 || return $?
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
    stderr warn TODO 1 # tasks-ignore
  } || {
    htd__current_cwd || return
  }
}


htd_man_1__current_cwd='List open paths for user (beloning to shell processes only)'
htd__current_cwd()
{
  lsof \
    +c 15 \
    -c '/^(bash|sh|ssh|dash|zsh)$/x' \
    -u $(whoami) -a -d cwd | tail -n +2 | awk '{print $9}' | sort -u
}
htd_of__current_cwd='list'
htd_als__current_paths=current-cwd


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
  test -n "$1" || set -- "paths" "$2"
  test_dir "$2" || return $?
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
    htd__current_cwd >$lsof

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



## Prefixes: named paths, or aliases for base paths

htd_man_1__prefixes='Manage local prefix table and index, or query cache.

  (op|open-files|read-lines)
    Default command. Pipe htd current-cwd to htd prefixes names.
    Set htd_path=1 to get pairs output.

Table
  list|names
    List prefix varnames from table.
  table
    Print user or default prefix-name lookup table

Index
  name Path-Name
    Resolve to real, absolute path and echo <prefix>:<localpath> by scanning
    prefix index.
  names (Path-Names..|-)
    Call name for each line or argument.
  pairs (Path-Names..|-)
    Get both path and name for each line or argument.
  expand (Prefix-Paths..|-)
    Expand <prefix>:<local-path> back to to absolute path.
  check
    ..

Cache
  all-paths|tree
    List cached prefixes and paths beneath them. See update-prefixes.
  update [TTL=60min [<persist=false>]]
    Update cache, read below.

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

    # Read from cache
    all-paths | tree )       htd_list_prefixes || return $? ;;
    update )                 htd_update_prefixes || return $? ;;

    # Read from index
    list )                   htd_prefix_names || return $? ;;
    table )                  htd_path_prefix_names || return $? ;;
    raw-table ) shift ;      cat $pathnames || return $? ;;
    table-id ) shift ;       echo $pathnames ; test -e "$pathnames" || return $? ;;
    name ) shift ;           htd_prefix "$1" || return $? ;;
    names ) shift ;          htd_prefixes "$@" || return $? ;;
    pairs ) shift ;          htd_path_prefixes "$@" || return $? ;;
    expand ) shift ;         htd_prefix_expand "$@" || return $? ;;

    check )
        # Read index and look for env vars
        htd_prefix_names | while read name
        do
            mkvid "$name"
            #val="${!vid}"
            val="$( eval echo \"\$$vid\" )"
            test -n "$val" || warn "No env for $name"
        done
      ;;

    op | open-files | read-lines ) shift
        htd__current_cwd | htd_prefixes -
      ;;

    current ) shift
        htd__current_cwd | htd_path_prefixes - |
          while IFS=' :' read path prefix localpath
        do
          trueish "$htd_act" && {
            older_than $path $_1HOUR && act='-' || act='+'
          }

          trueish "$htd_path" &&
              echo "$act $path $prefix:$localpath" ||
              echo "$act $prefix:$localpath"
        done
      ;;

  esac
  rm $index
}

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


htd_man_1__clean='Look for things to clean-up in given directory

TODO: in sequence:
- check (clean/sync) SCM dir, keep bare repo in /srv/$scm-local
- existing archive: check unpacked and cleanup unmodified files
- finally (on archive itself, other files left),
  use `htd find` to find existing copies and de-dupe
'
htd__clean()
{
  test -n "$1" || set -- .
  test -d "$1" || error "Dir expected '$?'" 1
  note "Checking $1 for things to cleanup.."

  local pwd=$(pwd -P) ppwd=$(pwd) spwd=. scm= scmdir=

  htd_clean_scm "$1"

  for localpath in $1/*
  do
    case "$localpath" in

      *.zip )
            htd__clean_unpacked "$localpath"
          ;;

      *.tar | *.tar.bz2 | *.tar.gz )
          ;;

      *.7z )
          ;;
    esac
  done

  for localpath in $1/*
  do
    test -f "$localpath" && {

      htd__file "$localpath"
    }
  done

  # Recurse
  for localpath in $1/*
  do
    test -d "$localpath" && {

      htd__clean "$localpath"
    }
  done

  htd__clean_empty_dirs
}
htd_grp__clean=box

htd__clean_empty_dirs()
{
  htd__find_empty_dirs "$1" | while read p
  do
    rmdir -p "$p" 2>/dev/null
  done
}


htd_man_1__clean_unpacked="Given archive, look for unpacked files in the "\
"neighbourhood. Interactively delete, compare, or skip.

"
htd_spc__clean_unpacked='clean-unpacked Archive [Dir]'
htd_env__clean_unpacked='P'
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
    } || error "Not a file or symlink: '$1'" 2
  }
  local  archive="$(basename "$1")" dir="$(dirname "$1")"
  # Resolve symbolic parts:
  set -- "$(cd "$dir"; pwd -P)/$archive" "$2"

  local oldwd="$(pwd)" \
      cnt=$(setup_tmpf .cnt) \
      cleanup=$(setup_tmpf .cleanup) \
      dirty=$(setup_tmpf .dirty)
  test ! -e "$cleanup" || rm "$cleanup"
  test ! -e "$dirty" || rm "$dirty"
  test -n "$P" || {

    # Default lookup path: current dir, and dir with archive basename name
    P="$2"
    archive_dir="$(archive_basename "$1")"
    test -e "$2/$archive_dir" && P="$P:$2/$archive_dir"
  }

  cd "$2"
  note "Checking for unpacked from '$1'.."
  #trueish "$strict" && {
    # Check all files based on checksum, find any dirty ones
    archive_update "$1" && {
      not_trueish "$dry_run" && {
        test ! -s "$cleanup" || {
          cat $cleanup | while read p
          do rm "$p"; done;
          note "Cleaned $(count_lines $cleanup) unpacked files from $1"
          rm $cleanup
        }
      } || {
        note "All looking clean $1 (** DRY-RUN **) "
      }
    }
  #} || {
  #  echo TODO: go about a bit more quickly archive_cleanup "$1"
  #}

  unset P

  cd "$oldwd"
  test ! -e "$dirty" && stderr ok "$1" || warn "Crufty $1" 1
}
htd_grp__clean_unpacked=archives


htd_man_1__note_unpacked='Given archive, note unpacked files.

List archive contents, and look for existing files.
'
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
htd_grp__note_unpacked=archives


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
htd_grp__test_unpacked=archives


htd__archive_list()
{
  archive_verbose_list "$@"
}
htd_grp__archive_list=archives



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


htd_man_1__src='TODO: this is for the src service/directory
See source for src.lib.sh wrapped as subcommands.
'
htd__src()
{
  test -n "$1" || set -- list
  case "$1" in

    list ) shift

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
  -vpaths [SUB]
      List all existing volume paths, or existing SUB paths (all absolute, with sym. parts)
  -disks [SUB]
      List all existing volume-ids with mount-point, or existing SUB paths.
      See -vpaths, except this returns disk/part index and `pwd -P` for each dir.
  find-container-volumes
      List container paths (absolute paths)
  check-volume Dir
      Verify Dir as either service-container or entry in one.
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

    check-volume ) shift ; test -n "$1" || error "Directory expected" 1
        test -d "$1" || error "Directory expected '$1'" 1
        local name="$(basename "$1")"

        # 1. Check that disk for given directory is also known as a volume ID

        # Match absdir with mount-point, get partition/disk index
        local abs="$(absdir "$1")"
        # NOTE: match with volume by looking for mount-point prefix
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
  disk.sh local-devices | while read disk
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
      eval $(sed 's/^volumes_main_/vol_/' $volume/.volumes.sh)

      test "$vol_prefix" = "$prefix" \
        || error "Prefix mismatch '$vol_prefix' != '$prefix' ($volume)" 1

      # Check for unknown service roots
      test -n "$vol_export_all" || vol_export_all=1
      trueish "$vol_export_all" && {
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
      test -n "$vol_aliases__1" \
        || error "Expected one aliases ($volume)"

      test -e "/srv/$vol_aliases__1"  || {
        error "Missing volume alias '$vol_aliases__1' ($volume)" 1
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

      note "Volumes OK: $disk_index.$vol_part_index $volume"

      unset srv \
        vol_prefix \
        vol_aliases__1 \
        vol_export_all

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



htd_man_1__count_lines='Count lines in file(s)'
htd_spc__count_lines='count-lines FILE [FILE..]'
htd__count_lines()
{
  count_lines "$@"
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
    rsync, e.g. to use include/exclude patterns.
'
htd__annex()
{
  test -n "$1" || error command 1
  test -n "$dry_run" || dry_run=true

  local srcinfo= rsync_flags=avzui act=$1 ; shift 1
  falseish "$dry_run" || rsync_flags=${rsync_flags}n

  get_srcinfo()
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
        test -n "$1" || error src 1
        test -n "$2" || error dest 1
        test -d "$2/.git/annex" || error annex-import 1

        local tmpd=$(setup_tmpd) srcinfo=$1 dest=$2 ; shift 2
        # See if remote-spec is local path, or else sync. Extra arguments
        # are used as rsync options (to pass on include/exclude patterns)
        test -e "$srcinfo" && tmpd=$srcinfo ||
          rsync -${rsync_flags} "$srcinfo" "$tmpd" "$@"

        {
            cd "$dest" ; trueish "$dry_run" && {
                echo git annex import --deduplicate $tmpd/*

            } || {
                git annex import --deduplicate $tmpd/* ||
                  warn "import returned $?"
                git status
            }
        }
        test ! -e "$srcinfo" || rm -r $tmpd
      ;;

    * ) error "'$act'?" 1 ;;

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
    }
  }
}
htd_pre__backup=htd_backup_prereq
htd_argsv__backup=htd_backup_argsv
htd_optsv__backup=htd_backup_optsv


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
    src_id=$(htd_prefix $src)
    $LOG file_warn $src_id "Listing info.." >&2
    $LOG header "Box Source" >&2
    $LOG header2 "Functions" $(htd__list_functions "$@" | count_lines) >&2
    $LOG header3 "Lines" $(count_lines "$@") >&2
    $LOG file_ok $srC_id >&2
  done
  $LOG done $subcmd >&2
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
  #test -z "$2" || {
  #  # Turn on scriptname output prefix if more than one file is given
  #  var_isset list_functions_scriptname || list_functions_scriptname=1
  #}
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
htd__vfs()
{
  test -n "$1" || set -- status
  local verify=1 act=$1
  shift ; htd_vfs_$act "$@" || return $?
}


htd_run__hoststat=f
htd__hoststat()
{
  test -n "$1" || set -- status
  upper=0 mkvid "$1"
  shift ; htd_hoststat_$vid "$@" || return $?
}


htd__volumestat()
{
  test -n "$1" || set -- status
  upper=0 mkvid "$1"
  shift ; htd_volumestat_$vid "$@" || return $?
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
  symlinks_id=${symlinks_id-script-mpe-symlinks}
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

    #host ) # XXX: tmux, launch/system/init daemon?
    #  ;;
    tmux ) # XXX: cant resolve the from shell
        htx__tmux show local
      ;;
    #* ) # XXX: schemes looking at ENV, ENV_NAME
    #  ;;
  esac
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
      realpath --relative-to="$OSX_PHOTOS" "$thumb"
  done

  find "$OSX_PHOTOS/Masters" -type f |
  while read master
  do
      realpath --relative-to="$OSX_PHOTOS" "$master"
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



htd_man_1__catalog='Build file manifests

  fsck CATALOG
    verify file checksums
  validate CATALOG
    verify catalog document schema
  list
    find catalog documents
'
htd__catalog()
{
  upper=0 mkvid "$1" ; shift
  htd_catalog_$vid "$@" || return $?
}

htd_man_1__catalog_list='Find local catalogs'
htd_als__catalogs='catalog list'
htd_man_1__catalog_fsck='File-check entries from catalog with checksums'
htd_als__fsck_catalog='catalog fsck'


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
  local type_= expr_= act="$2" no_act="$3"
  foreach_setexpr "$1" ; shift 3
  foreach "$@"
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
  foreach_setexpr "$1" ; shift
  mode_=1 htd_filter "$@"
}


htd_man_1__filter_out='Return non-matches for glob, regex or other expression

See `htd help filter`.
'
htd_spc__filter_out='filter EXPR [ - | PATH... ]'
htd__filter_out()
{
  local type_= expr_= mode_=
  foreach_setexpr "$1" ; shift
  mode_=0 htd_filter "$@"
}


htd_man_1__init='Initialize project ID

Look for vendorized dir <vendor>.com/$NS_NAME/<project-id> or get a checkout.
Link onto prefix in Project-Dir if not there.
Finish running local htd run init && pd init.
'
#htd_spc__init='init [ [Vendor:][Ns-Name][/]Project ]'
htd_spc__init='init [ Project [Vendor] [Ns-Name] ]'
htd_run_init=pqi
htd__init()
{
  #test -n "$1" || set -- . TODO: detect from cwd
  test -n "$2" || {

    test -z "$3" && {
      # Take first found in lists for all vendors?
      true
    } || {
      true
    }
  }
  error TODO 1
  cd ~/project/$pd_prefix
  htd scripts id-exist init && {
    htd run init || return $?
  }
  #pd init
}


htd_man_1__docs='Documents'
htd_run__docs=f

htd_man_1__doc='Document'
htd_run__doc=f
htd__doc()
{
  test -n "$1" || set -- main-files
  upper=0 mkvid "$1"
  shift ;
  func_exists ${base}_doc_$vid && cmd=${base}_doc_$vid || {
    func_exists doc_$vid || error "$vid" 1
    cmd=doc_$vid
  }
  $cmd "$@" || return $?
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

Each basename must test OK. '
htd__resolve_modified()
{
  vc_modified | while read name
    do
      basename=$(filestripext "$name");
      c=_- mkid "$basename";
      note "$name: $basename: $id";
      echo "$id $name"
  done | join_lines - ' ' | while read component files
  do
    htd run test $component && git add $files
  done
}


# -- htd box insert sentinel --



# Script main functions

htd_main()
{
  local scriptname=htd base=$(basename "$0" .sh) \
    scriptpath="$(cd "$(dirname "$0")"; pwd -P)" \
    upper= \
    package_id= package_cwd= package_env= \
    subcmd= subcmd_alias= subcmd_args_pre= \
    arguments= prefixes= options= \
    passed= skipped= error= failed=

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

          main_debug

          htd_load "$@" || warn "htd-load ($?)"
          var_isset verbosity || local verbosity=5
          test -z "$arguments" -o ! -s "$arguments" || {

            info "Setting $(count_lines $arguments) args to '$subcmd' from IO"
            set -f; set -- $(cat $arguments | lines_to_words) ; set +f
          }

          test -n "$subcmd_args_pre" || set -- $subcmd_args_pre "$@"
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
  lst_init_etc
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
}

htd_init()
{
  # XXX test -n "$SCRIPTPATH" , does $0 in init.sh alway work?
  test -n "$scriptpath"
  local __load_lib=1
  export SCRIPTPATH=$scriptpath
  . $scriptpath/util.sh || return $?
  lib_load
  . $scriptpath/box.init.sh
  box_run_sh_test
  lib_load htd meta
  lib_load box date doc table disk remote package service archive \
      prefix volumestat vfs hoststat scripts tmux vcflow tools schema ck net \
      catalog tasks journal
  case "$uname" in Darwin ) lib_load darwin ;; esac
  . $scriptpath/vagrant-sh.sh
  disk_run
  # -- htd box init sentinel --
}

htd_lib()
{
  local __load_lib=1
  . $scriptpath/match.sh
  lib_load list ignores
  # -- htd box lib sentinel --
  set --
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
