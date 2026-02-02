x11_als_pre=X11.Alias

declare -gA \
x11_als_als=(

  [x11.win.geom]=xdotool.window.geometry
  [x11.win.geom.shell]=xdotool.window.geometry-shell
)

declare -gA \
x11_als_ssc=(

  [xdotool.dump.geom]=\
' local class_or_name window_id
  for class_or_name
  do
    xdotool.windowid.for-class-or-name "$class_or_name" window_id ||
      failerr "E$? nothing for ${class_or_name} (ignored)" || continue

    echo "win_geom[\"${class_or_name^^}\"]="
    < <(xdotool getwindowgeometry --shell "$window_id") \
    sed '\''s/^.*$/'\''"win_geom[\"${class_or_name^^}\"]"'\''+="&\ "/'\''
  done'

  [xdotool.raise.xapps]=\
' local WINDOW SCREEN X Y
  source <(xdotool getmouselocation --shell)

  xdotool search --name xeyes windowactivate
  xdotool search --name xload windowactivate
  xdotool search --name xman windowactivate

  xdotool mousemove 0 0
  xdotool mousemove $X $Y'

  [xdotool.restore.geom]=\
' local class_or_name window_id cache=/var/local/statusdir/$HOSTNAME,$USER,geom,win,data.bash
  local -A win_geom
  local -n window_geom='\''win_geom["${class_or_name^^}"]'\''
  [[ ! -s $cache ]] || . "$cache"
  for class_or_name
  do
    xdotool.windowid.for-class-or-name "$class_or_name" window_id ||
      failerr "E$? nothing for ${class_or_name} (ignored)" || continue

    eval "$window_geom"
    echo Restoring $class_or_name $window_id #${window_geom}
    xdotool windowmove $window_id $X $Y
    xdotool windowsize $window_id $WIDTH $HEIGHT
  done'

  [xdotool.save.geom]=\
' local cache=/var/local/statusdir/$HOSTNAME,$USER,geom,win,data.bash
  echo "declare -A win_geom" >| "$cache"
  xdotool.dump.geom "$@" | grep -v WINDOW= >> "$cache"'

  [xdotool.window.geometry]='xdotool selectwindow getwindowgeometry'
  [xdotool.window.geometry-shell]='xdotool selectwindow getwindowgeometry --shell'
  [xdotool.window.name]='xdotool selectwindow getwindowname'
  [xdotool.window.pid]='xdotool selectwindow getwindowpid'
  [xdotool.window.kill]='xdotool selectwindow windowkill'
  [xdotool.window.stack-lower]='xdotool selectwindow windowlower'
  [xdotool.window.stack-raise]='xdotool selectwindow windowraise'

  # XXX: we expect one for each but theoretically this needs to check
  # also really want to query instance always together with class...
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

declare -gA \
x11_als_hooks=(

[user+x11+load]=\
': user-data-file "${uc_x11_user_bash:=/var/local/statusdir/x11,user.data.bash}"
cache_loadmaps "$uc_x11_user_bash" uc_x11_cmd_name_opts'

)

# Id: als,x11                                    vim:set ft=bash sw=2 sts=2 et:
