#!/bin/sh


box_lib_load()
{
  test -n "$BOX_DIR" || error "box-load: expected BOX-DIR env" 1
  test -d "$BOX_DIR" || mkdir -vp $BOX_DIR
  test -n "$hostname" || hostname="$(hostname -s | tr 'A-Z' 'a-z')"
  test "$(pwd)" = "$(pwd -P)" || warn "current dir seems to be aliased"
  mkvid $(pwd)
  nid_cwd=$vid
  unset vid

  test -n "$box_name" || box_name=$hostname

  test -e "$BOX_DIR/bin/$box_name" \
    && box_file="$BOX_DIR/bin/$box_name" || noop
}

box_docs()
{
  noop
  #echo 'Docs:'
}


### Util functions

box_find_localscript()
{
  # XXX: or scan for function before determining script
  test -e "$local_script" && return || {
    warn "No local_script for $hostname:$(pwd)"
    return 1
  }
}

box_find_namedscript()
{
  test -n "$named_script" || named_script=$BOX_BIN_DIR/$script_name
  test -e "$named_script" && return || {
  echo BOX_BIN_DIR=$BOX_BIN_DIR
    warn "No named_script for $script_name"
    return 1
  }
}

box_req_files_localscript()
{
  local r=0

  box_find_localscript && {
    log "Including local-script $local_script"
    . $local_script
    script_files="$script_files $local_script"
  } || r=1

  box_find_namedscript && {
    log "Including named-script $named_script"
    . $named_script
    script_files="$script_files $named_script"
  } || r=$(( $r + 1 ))

  test -e "$uconf_script" && {
    log "Including uconf-script $uconf_script"
    . $uconf_script
    script_files="$script_files $uconf_script"
  } || r=$(( $r + 1 ))

  test $r -lt 3 || return $r
}

box_init_local()
{
  subbox_name="${script_name}:${script_subcmd_name}"
  test -n "$local_script" || local_script=$BOX_DIR/${script_name}/${nid_cwd}.sh
  test -n "$uconf_script" || uconf_script=$BOX_DIR/$script_name-localscripts.sh
  test -e $uconf_script && warn "TODO clean $uconf_script"
  case "$1" in 1 )
      test -e "$named_script" || touch $named_script
      box_req_files_localscript
      ;;
    2 )
      box_req_files_localscript || return 1
      ;;
    * )
      box_req_files_localscript || noop
      ;;
  esac
  locate_name
}

box_init_script()
{
  touch $1
  chmod +x $1
  echo "#!/bin/sh" > $1
  echo >> $1
}

# 1:func-name 2:file-name[:line-number] 3:script
box_add_function()
{
  test -n "$1" || err "function name arg required" 1
  test -n "$2" || err "file name arg required" 1
  test -n "$3" || err "function body arg required" 1

  fnmatch "*:[0-9]*" $2 && {

    info "Inserting funtion $1"
    add_function "$1" "$2" "$3"
  } || {

    info "Appending funtion $1 for $2"

    echo "$1()" >> $2
    echo "{" >> $2
    echo "$3" >> $2
    echo "}" >> $2
    echo >> $2
  }
}

box_add_idx()
{
  echo "$1()" >> $2
  echo "{" >> $2
  echo "  $func" >> $2
  echo "}" >> $2
  echo >> $2
}

box_grep()
{
  file_where_before "$@" || return $?
  test -n "$where_line" || return 1
}

# box-script-insert-point FILE SUBCMD PROPERTY BOX-PREFIX
# Return line-nr before function
box_script_insert_point()
{
  local subcmd_func= grep_file=$1
  shift
  local subcmd_func=$(try_local "$@")
  local where_line= line_number= p='^'${subcmd_func}'()$'
  box_grep "$p" "$grep_file" || {
    error "box-script-insert-point: invalid $subcmd_func ($grep_file)" 1
  }
  echo $line_number
}

box_sentinel_indent()
{
  local where_line= line_number=
  box_grep $1 $2 || {
    error "box-sentinel-indent: invalid sentinel $1 ($2)" 1
  }
  echo "$where_line"
}

box_name_args()
{
  test -n "$1" && {
    name="$1" ; shift 1 ; c=$(( $c + 1 ))
  } || name="${hostname}"

  test -n "$1" \
    && { cmd="$1"; shift 1; c=$(( $c + 1 )); } \
    || note "using default cmd='run'"
}

box_run_cwd()
{
  test -n "$1" || error "box-run-cwd: req name" 1
  test -n "$2" || error "box-run-cwd: req cmd" 1
  local func=$(echo $func_pref$1__$2 | tr '/-' '__')
  local tcwd=$1
  test -d $tcwd || error "box-run-cwd: no dir $tcwd" 1
  shift 2
  cd $tcwd
  $func "$*"
}

box_init_args()
{
  # subcmd-name
  test -n "$1" && {
    subcmd="$1" ; c=$(( $c + 1 ))
  } || subcmd=run
  # script-name
  test -n "$2" && {
    script_name="$2" ; c=$(( $c + 1 ))
  } || {
    script_name="${hostname}"
  }
}

box_list_libs()
{
  test -n "$1" || set -- "$0" "$(basename "$0")"
  test -n "$2" || set -- "$1" "$(basename "$1")"

  test -e "$1" || {
    error "box-list-libs: no script $1"
    return 1
  }

  local \
    line_offset="$(box_script_insert_point $1 "" lib $2)" \
    sentinel_grep=".*#.--.${2}.box.lib.sentinel.--"

  test -n "$line_offset" || error "box-list-libs: line_offset empty for '$1' lib '$2'" 1

  box_grep $sentinel_grep $1
  local line_diff=$(( $line_number - $line_offset - 2 ))

  test -n "$line_diff" || error "box-list-libs: line_diff empty" 1
  fnmatch "-*" "$line_diff" &&
    error "box-list-libs: negative line_diff: $line_diff" 1 || noop

  test -z "$dry_run" || {
    debug "named_script='$1'"
    debug "scan after line $line_offset"
    debug "scan up to line $line_number"
    debug "scan total lines $line_diff"
    debug "nid_cwd='$nid_cwd'"
    debug "'$BOX_BIN_DIR/*'"
    info "** DRY RUN ends **" 0
  }

  test $line_diff -eq 0 || {
    tail -n +4 | tail -n +$line_offset | head -n $line_diff;
  } < $1
}


# XXX: goes here at box.lib? or into main.lib? Unused still

box_init()
{
  test -n "$UCONF" || error "box-init: UCONF" 1
  cd $UCONF
}


box_update()
{
  test -n "$UCONF" || error "box-update: UCONF" 1
  cd $UCONF

  test -n "$box_host" || box_host=$hostname
  test -n "$box_user" || box_user=$(whoami)

  on_host "$box_host" || ssh_req $box_host $box_user
  run_cmd "$box_host" "cd ~/.conf && git fetch --all && git pull"
  run_cmd "$box_host" "cd ~/.conf && git fetch --all && git pull"

  ansible-playbook -l $box_host ansible/playbook/user-conf.yml
  #ansible-playbook -l $box_host ansible/playbook/system-update.yml
  #ansible-playbook -l $box_host ansible/playbook/user-env-update.yml
}


box_src_lib()
{
  test -n "$*" || set -- "$0" "$1"
  box_src="$(dry_run= box_list_libs "$@" | while read src path args; \
    do
      fnmatch "  source " "$src" || {
        fnmatch "  . " "$src" && continue;
      }
      eval echo "$path"; done)"
  box_lib="$box_src"
}

