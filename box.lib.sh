#!/usr/bin/env sh

box__load()
{
  test -d "$BOX_DIR" || mkdir -vp $BOX_DIR
  test -n "$hostname" || hostname=$(hostname -s)
  test "$(pwd)" = "$(pwd -P)" || warn "current dir seems to be aliased"
  mkvid $(pwd)
  nid_cwd=$vid
  unset vid
}

box_commands()
{
  echo 'Commands:'
  echo '    -r|run                      '
  echo '    -h|help                     '
  echo '    -e|edit                     Edit local script or abort. '
  echo '    -E|edit-main                Edit main script. '
  echo '    -i|init                     Init local script with name. '
  echo '    -n|new                      '
  echo '    -f|function                 '
  echo ''
}

box_docs()
{
  echo 'Docs:'
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
  named_script=$BOX_BIN_DIR/$script_name
  test -e "$named_script" && return || {
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
  box_name="${script_name}:${script_subcmd_name}"
  local_script=$BOX_DIR/${script_name}/${nid_cwd}.sh
  uconf_script=$BOX_DIR/$script_name-localscripts.sh
  #test -e $uconf_script && warn "TODO clean $uconf_script"
  box_req_files_localscript
  test -z "$1" -o $? -gt 0 || return 1
  global_func_name=c_${script_name}__${script_subcmd_name}
  local_func_name=c_${script_name}__local__${nid_cwd}__${script_subcmd_name}
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

    file_insert_at $2 "$(cat <<-EOF
$1()
{
$3
}

EOF
)
"

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
  file_where_before $1 $2
  test -n "$where_line" || return 1
}

box_script_insert_point()
{
  local where_line= line_number=
  local p='^'${script_name}'__main()$'
  box_grep $p $1 || {
    error "invalid ${script_name}__main ($1)" 1
  }
  echo $line_number
}

box_sentinel_indent()
{
  local where_line= line_number=
  box_grep $1 $2 || {
    error "invalid sentinel $1 ($2)" 1
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
  test -n "$1" || error "req name" 1
  test -n "$2" || error "req cmd" 1
  local func=$1__$2
  local tcwd=$(echo $1 | tr '_' '/')
  test -d $tcwd || error "no dir $tcwd" 1
  shift 2
  cd $tcwd
  $func "$*"
}



