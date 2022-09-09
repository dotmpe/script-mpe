#!/bin/sh

### Desktop.lib: deal certain graphic OS stuff

#shellcheck disable=2034,2015

# Auto-detect desktop config system
# XXX: only commands for gnome and xfce
desktop_conf ()
{
  if sys_running "gsd-xsettings" # Gnome Settings Daemon
  then DESKTOP_CONF=gnome
  elif sys_running "xfsettingsd" # XFCE4
  then DESKTOP_CONF=xfce
  else return 1
  fi
}

xfce_widget_theme () # ~ [<New-Theme>]
{
  test $# -eq 1 && set -- "-s" "$1"

  xfconf-query -c xsettings -p /Net/ThemeName "$@"
}

gnome_widget_theme () # ~ [<New-Theme>]
{
  test $# -eq 1 && {
    gsettings set org.gnome.desktop.interface gtk-theme "$1"
    return
  } || {
    gsettings get org.gnome.desktop.interface gtk-theme
  }
}

dirs_themes ()
{
  for dd in $(echo ${XDG_DATA_DIRS:-/usr/local/share:/usr/share:$HOME/.local/share} | tr ':' ' ')
  do test -d "$dd/themes" || continue
    echo "$dd/themes"
  done
  test -d "$HOME/.themes" && echo "$HOME/.themes"
  unset dd
}

# XXX: I have no clue where to look. Seems best left to the GUI.
list_widget_themes ()
{
  for td in $(dirs_themes)
  do
    for t in "$td"/*
    do
      test -d "$t/gtk-3.0" -o -d "$t/gtk-3.20" || continue
      basename "$t"
    done
  done
}

gnome_desktop_image ()
{
  gsettings get org.gnome.desktop.background picture-uri
  gsettings get org.gnome.desktop.background picture-options
}


#
