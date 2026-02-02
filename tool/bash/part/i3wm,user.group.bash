# Copyright: (C) 2025 qwrt <qwrt@t460s>
#
# .group.bash file, see User-Conf us-part for specification.
#
# Distributed under terms of the MIT license.

user_i3wm_pre=User.I3wm
user_i3wm_cnk=8eca66a3
user_i3wm_fun=(
  .start-with-name
  .subscribe+script
  .subscribe+script.window+restore+update
  .subscribe+user
)

declare -gA \
user_i3wm_hooks=(

[user+i3wm+load]=\
': user-data-file "${uc_i3wm_user_bash:=/var/local/statusdir/i3wm,user.data.bash}"
cache_loadmaps "$uc_i3wm_user_bash" uc_wm_evt_hook'

)

declare -gA \
user_i3wm_als=(
  [.exit-wm]='i3-msg exit'
  [.outputs-json]='i3-msg -t get_outputs'

  [.start-program]='i3-msg exec'
# TODO: integrate i3wm-exit into here as .wm-session

  [.subscribe+json+config]='.subscribe+user'
  [.subscribe+json+script]='.subscribe+script'
  [.tree-json]='i3-msg -t get_tree'
  [.workspaces-json]='i3-msg -t get_workspaces'
)

declare -gA \
user_i3wm_ssc=(

  [.container-json]='< <(i3-msg -t get_tree) jq -r '\''.. | select(.window? == '\'\"\$1\"\'')'\'

  [.id-list]=\
'< <(i3-msg -t get_tree) jq -r '\''.. | .id? // empty'\'

  # XXX: experiments getting JSON path aka object path in xpath notation
  [.id-list+paths+pretty]=\
'< <(i3-msg -t get_tree) jq -r '\''
  [ ( [ .id, .type, .window, .window_type, "/" ] | join(" ")),
    paths(.id?) as $p | [
      (getpath($p) | [ .id, .type, .window, .window_type ] | join(" ")),
      ($p | map(if type=="number" then "[\(.)]" else "/\(.)" end) | join(""))
    ] | join(" ")
  ] | join("\n")'\'

  # FIXME: these look interesting but doesnt work, see .id-list
  [.id-tree+grok]=\
'jq -r '\''
  def indent(n): "  " * n;
  def tree($depth):
    . as $node |
    indent($depth) + (.id | tostring) +
    if .nodes? | length > 0 or .floating_nodes? | length > 0 then
      " \u251c\u2500 " + (.name // .window_properties?.class // "container") + "\n" +
      (.nodes // [] | .[] | tree($depth + 1)) +
      (.floating_nodes // [] | .[] | tree($depth + 1))
    else
      " (" + (.window_properties?.class // "leaf") + ")"
    end;
  tree(0)
'\'' < <(i3-msg -t get_tree)'
  [.id-tree+grok2]=\
'jq -r '\''
  def t($d): "  "*$d + (.id|tostring) +
             if (.nodes|length>0 or .floating_nodes|length>0) then
               " ├─ " + (.name//.window_properties?.class//"container") + "\n" +
               (.nodes//[] | .[] | t($d+1)) +
               (.floating_nodes//[] | .[] | t($d+1))
             else " (" + (.window_properties?.class//"leaf") + ")" end;
t(0)'\'' < <(i3-msg -t get_tree)'

  [.window-info]='< <(i3-msg -t get_tree) jq -r '\''.. | select(.window? == '\'\"\$1\"\'') | [ .id, .layout, .border, .marks, .rect, .geometry, .output ]'\'
  [.window-properties]='< <(i3-msg -t get_tree) jq -r '\''.. | select(.window? == '\'\"\$1\"\'') | .window_properties'\'

  [.windowid-list]=\
'< <(i3-msg -t get_tree) jq -r '\''.. | .window? // empty'\'

  # XXX: these (with paths(...)) exclude the root
  [.windowid-list+paths+subs]=\
'< <(i3-msg -t get_tree) jq -r '\''
  paths(.id?) as $p | [ (getpath($p) | .window), ($p | join(".")) ] | join(" ")'\'

)


User.I3wm.start-with-name ()
{
  : about "set instance which is WM_CLASS' first value (second is class--often capitalized)"

  local -n _usr_i3_cmdnameopt='uc_x11_cmd_name_opts["$cmd"]'
  local cmd=${1%% *} rest
  [[ ${_usr_i3_cmdnameopt:+set} ]] ||
    failerr "X11 name (instance) option unsupported for ${cmd@Q}" || return

  [[ ${#1} -eq ${#cmd} ]] || rest=${1: ${#cmd}+1}
  User.I3wm.start-program "$cmd $_usr_i3_cmdnameopt${rest:+ ${rest}}" "${@:2}"
}

User.I3wm.subscribe+script ()
{
  [[ ${1:0:1} != . ]] || set -- "$FUNCNAME$1" "${@:2}"
  local -n _wm_evt_hook='uc_wm_evt_hook["$change"]'
  # shellcheck disable=2162
  while read msg_js
  do
    # using native string matching to parse,
    # for speed but avoid buggy JSON parse errs too
    shell-json.scan-atr+snip msg_js change '' '' sub_js &&
    "${@}" "$change" "$sub_js" "$msg_js" ||
    #case "$change" in
    #( close | floating | focus | new | null | run | title )
    #;; * ) false; esac ||
      >&2 echo "$FUNCNAME: Unexpected/E$? error parsing IPC message: ${msg_js@Q}"
  done < <( i3-msg -m -t subscribe '"window"' )
}

User.I3wm.subscribe+script.window+restore+update ()
{
  local change=$1 sub_js=$2 msg_js=$3
  case "$change" in
  ( close )
      shell-json.scan-atr+snip sub_js c_id '"container":{"id":' ',' cont_js &&
      echo $change container $c_id #sub: $cont_js
    ;;
  ( floating )
      shell-json.scan-atr+snip sub_js c_id '"container":{"id":' ',' cont_js &&
      shell-json.scan-atr cont_js floating &&
      case "$floating" in
      ( user_on )
          echo $change container $c_id new: $floating #sub: $cont_js
        ;;
      ( user_off ) ;;
        * ) false
      esac
    ;;
  ( focus )
      shell-json.scan-atr+snip sub_js c_id '"container":{"id":' ',' cont_js &&
      echo $change container $c_id #sub: $cont_js
    ;;
  ( new )
      shell-json.scan-atr+snip sub_js c_id '"container":{"id":' ',' cont_js &&
      echo $change container $c_id #sub: $cont_js
    ;;
  ( title ) ;;
    * ) false
  esac ||
    >&2 echo "$FUNCNAME: Unexpected/unknown IPC message: ${msg_js@Q}"
}

User.I3wm.subscribe+user ()
{
  [[ ${uc_wm_evt_hook[*]:+set} ]] ||
    us_part --hooks:user+i3wm+load user-i3wm || return

  local -n _wm_evt_hook='uc_wm_evt_hook["$change"]'
  # shellcheck disable=2162
  while read msg_js
  do
    # using native string matching to parse,
    # for speed but also avoid buggy JSON parse errs
    shell-json.scan-atr+snip msg_js change '' '' sub_js && {
    [[ ${_wm_evt_hook:+set} ]] &&
    #local -n _wm_evt_cmd=$_wm_evt_hook &&
    #"${_wm_evt_[@]}" "$change" "$sub_js" "$msg_js" ||
    eval "${_wm_evt_hook} \"$change\" ${sub_js@Q} ${msg_js@Q}" ||
      >&2 echo "$FUNCNAME: E$? running hook: ${_wm_evt_hook@Q} for $change"
  } ||
      >&2 echo "$FUNCNAME: Unexpected/E$? error parsing IPC message: ${msg_js@Q}"
  done < <( i3-msg -m -t subscribe '"window"' )
}


# Id: i3wm,user                                  vim:set ft=bash sw=2 sts=2 et:
