x11_als_pre=X11.Alias
x11_als_cnk=b3d9dd0e
x11_als_fun=()

declare -gA \
x11_als_hooks=(

[user+x11+load]=\
': user-data-file "${uc_x11_user_bash:=/var/local/statusdir/x11,user.data.bash}"
cache_loadmaps "$uc_x11_user_bash" uc_x11_cmd_name_opts'

)

declare -gA \
x11_als_als=(

  [x11.root.info+xprop]='xprop -root'
  [x11.root.info+xwininfo]='xwininfo -root'
  [x11.root.info+i3+json]='< <(i3-msg -t get_tree) jq "del(.nodes, .floating_nodes)"'

  [x11.win.geom+xdotool]=xdotool.window.geometry
  [x11.win.geom.shell+xdotool]=xdotool.window.geometry-shell

  [x11.win.id+sel]='xdotool selectwindow'

  [x11.win.info+for]=User.I3wm.window-info
  [x11.win.info+root+xwininfo]='xwininfo -children -root'
  # FIXME: this doesnt do work for root while xdotool selectwindow does return
  # some id. Currently, using window id so root id is different?
  [x11.win.info+sel+i3]='User.I3wm.window-info $(xdotool selectwindow)'
  [x11.win.info+sel+xwininfo]='xwininfo -tree'

  [x11.win.json]=User.I3wm.container-json
  [x11.win.json+sel]='User.I3wm.container-json $(xdotool selectwindow)'

  [x11.win.new]=User.I3wm.start-program
  [x11.win.new+withname]=User.I3wm.start-with-name

  [x11.win.props+sel]=xprop
  [x11.win.props+i3+for]=User.I3wm.window-properties
  [x11.win.props+sel+i3]='User.I3wm.window-properties $(xdotool selectwindow)'

  # XXX: lists all containers, not just everything that is a window (id)?
  [x11.win.list+i3]='User.I3wm.id-list'
  [x11.win.list+i3+pretty]='User.I3wm.id-list+paths+pretty'
  [x11.win.list+wmctrl]='wmctrl -l'
  [x11.win.list+xdotools]='xdotool search . --name . --class . --classname .'
  [x11.win.list+xlsatoms]='grep -i window < <(xlsatoms)'
  [x11.win.list+xprop]='xprop -root _NET_CLIENT_LIST'
  [x11.win.list+xwininfo]='xwininfo -tree -root'

)

declare -gA \
x11_als_ssc=(

  [xdotool.dump.geom]=\
' local class_or_name window_id
  xdotool.list-runner "$@" .dump-geom'

  [xdotool.raise.xapps]=\
' local WINDOW SCREEN X Y
  source <(xdotool getmouselocation --shell)

  xdotool search --name xeyes windowactivate
  xdotool search --name xload windowactivate
  xdotool search --name xman windowactivate

  xdotool mousemove 0 0
  xdotool mousemove $X $Y'

  [xdotool.list-runner]=\
'local handler
  (($#)) || return ${_E_GAE:?}
  eval "handler=( ${@: -1:1} )"
  [[ ${handler[0]:0:1} != . ]] || handler[0]=${FUNCNAME}${handler[0]}
  set -- "${@: 1:$#-1}"
  for class_or_name
  do
    case "$class_or_name" in
    ( @* ) xdotool.windowid.for-class "^${class_or_name:1}\$" window_id ;;
    ( =* ) xdotool.windowid.for-classname "^${class_or_name:1}\$" window_id ;;
    ( * ) xdotool.windowid.for-class-or-name "^$class_or_name\$" window_id ;;
    esac ||
      failerr "E$? nothing for ${class_or_name} (ignored)" || continue
    logger -s -p user.info "Found window $window_id for $class_or_name"
    "${handler[@]}"
  done'

  [xdotool.list-runner.check-geom]=\
'   eval "$_win_geom"
    #echo Checking $class_or_name $window_id #${_win_geom}
    geomstr=$(xdotool getwindowgeometry --shell "$window_id")
    geomstr=${geomstr//$'\''\n'\''/ }
    geomstr=${geomstr#WINDOW=* }
    [[ ${_win_geom} == "${geomstr} " ]] || {
      echo no match $class_or_name
      echo "${_win_geom@Q} vs ${geomstr@Q}"
    }'

  [xdotool.list-runner.dump-geom]=\
' echo "win_geom[\"${class_or_name^^}\"]="
  < <(xdotool getwindowgeometry --shell "$window_id") \
  sed '\''s#^.*$#'\''"win_geom[\"${class_or_name^^}\"]"'\''+="&\ "#'\'

  [xdotool.list-runner.restore-geom]=\
'   eval "$_win_geom"
    echo Restoring $class_or_name $window_id #${_win_geom}
    xdotool windowmove $window_id $X $Y
    xdotool windowsize $window_id $WIDTH $HEIGHT'

  [xdotool.load-cache]=\
' local cache=/var/local/statusdir/$HOSTNAME,$USER,geom,win,data.bash
  [[ ! -s $cache ]] || . "$cache"'

  [xdotool.restore.geom]=\
' local class_or_name window_id cache=/var/local/statusdir/$HOSTNAME,$USER,geom,win,data.bash
  local -A win_geom
  local -n _win_geom='\''win_geom["${class_or_name^^}"]'\''
  [[ ! -s $cache ]] || . "$cache"
  xdotool.list-runner "$@" .restore-geom'

  [xdotool.save.geom]=\
' local newcache=/var/local/statusdir/$HOSTNAME,$USER,new,geom,win,data.bash
  local cache=/var/local/statusdir/$HOSTNAME,$USER,geom,win,data.bash
  echo "declare -gA win_geom" >| "$newcache" &&
  xdotool.dump.geom "$@" | grep -v WINDOW= >> "$newcache" &&
  diff -bq "$cache" "$newcache" && echo no changes || echo resolve cache changes'

  [xdotool.window.geometry]='xdotool selectwindow getwindowgeometry'
  [xdotool.window.geometry-shell]='xdotool selectwindow getwindowgeometry --shell'
  [xdotool.window.name]='xdotool selectwindow getwindowname'
  [xdotool.window.pid]='xdotool selectwindow getwindowpid'
  [xdotool.window.kill]='xdotool selectwindow windowkill'
  [xdotool.window.stack-lower]='xdotool selectwindow windowlower'
  [xdotool.window.stack-raise]='xdotool selectwindow windowraise'

  # XXX: we expect one for each but theoretically this needs to check
  # also really want to query instance always together with class...
  [xdotool.windowid.for-class]=\
' : input "${1:?Window class name}"
  : input "${2:?Destination variable name}"
  local -n _xdt_winid=${2}
  _xdt_winid=$(xdotool search --class "$1" | head -n 1) &&
  [[ ${_xdt_winid:+set} ]]'

  [xdotool.windowid.for-classname]=\
' : input "${1:?Window instance name}"
  : input "${2:?Destination variable name}"
  local -n _xdt_winid=${2}
  _xdt_winid=$(xdotool search --classname "$1" | head -n 1) &&
  [[ ${_xdt_winid:+set} ]]'

  [xdotool.windowid.for-class-or-name]=\
' : input "${1:?Window class or instance name}"
  : input "${2:?Destination variable name}"
  local -n _xdt_winid=${2}
  _xdt_winid=$(xdotool search --classname "$1" | head -n 1) &&
  [[ ${_xdt_winid:+set} ]] ||
    _xdt_winid=$(xdotool search --class "$1" | head -n 1)
  [[ ${_xdt_winid:+set} ]]'

  # XXX: there is not enough here to automate scripting on. need external meta
  # data for automatic layout. See i3-msg.events.shell
  [xprop.events.shell+example]=\
'xprop -root -spy _NET_ACTIVE_WINDOW | while read -r LINE
do
  # TODO: fix x2x mouse reentry on monitor without focus here
  [[ $LINE == "_NET_ACTIVE_WINDOW(WINDOW):"* ]] || {
    failerr "Unrecognized line ${LINE@Q} (ignored)"
    continue
  }
  NEW_FOCUS=${LINE#"_NET_ACTIVE_WINDOW(WINDOW): window id # "}
  #WIN_NAME=$(xdotool getwindowname "$NEW_FOCUS")
  #WIN_PID=$(xdotool getwindowpid "$NEW_FOCUS")
# '\''$WIN_NAME'\''
  echo "Focus changed: now on ${NEW_FOCUS}, previous ${WIN_FOCUS-}"
  # XXX: cannot re-focus while in loop? may need to async this: i3.raise-dash-apps
  WIN_FOCUS=$NEW_FOCUS
done'
)

# Id: als,x11                                    vim:set ft=bash sw=2 sts=2 et:
