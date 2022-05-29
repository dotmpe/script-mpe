#!/bin/sh

### Library for interrogating Xorg system.

#shellcheck disable=SC2046 # Quote to prevent word splitting.
#shellcheck disable=SC2086 # Double quote to prevent globbing and word splitting.

xorg_lib_depends="os* "
xorg_lib_settings=xorg_settings_sh


xorg_display () # ~ ['primary'|'aux'|'all'|<Glob>] # List display names
{
  test $# -gt 0 || set -- all
  for spec in "$@"
  do
    case "$spec" in
      ( "primary" ) primary ;;
      ( "aux" ) xorg_info_aux | cut -d' ' -f1 ;;

      ( "all" )
          true "${displays:=$(xorg_names)}"
          echo "$displays" ;;

      ( * )
          true "${displays:=$(xorg_names)}"
          for display in $displays
          do case "$display" in ( $spec ) echo "$display" ;; esac
          done ;;
    esac
  done
}

xorg_display_info () # ~ [<Name>] # List xrandr lines (with display names and resolution/offset info)
{
  test $# -gt 0 || set -- ".*"
  xorg_info_connected | grep "^$1 " | sed 's/\( connected\| primary\)//g'
}

#shellcheck disable=SC2162 # read without -r will mangle backslashes.
xorg_dpi () # ~ # Report actual DPI for displays.
{
  xorg_display_info |
      sed 's/ (.*)//
        s/+/ /g
        s/\([0-9]\)x\([0-9]\)/\1 \2/
        s/\([0-9]\)mm/\1/g' |
      while read name resx resy _ _ width _ height
      do
        widthI=$(echo "scale=3; $width / 25.4" | bc)
        heightI=$(echo "scale=3; $height / 25.4" | bc)
        dpi_h=$(echo "scale=0; $resx / $widthI" | bc)
        dpi_v=$(echo "scale=0; $resy / $heightI" | bc)

        echo "$name $dpi_h $dpi_v"
      done
}

xorg_info () # ~
{
  case "${1:-}" in
      ( screen ) shift; xorg_screen_info "$@"; return ;;
      ( screens ) xorg_screen_info "$@"; return ;;

      ( displays | display ) shift;;
  esac
  xorg_display_info "$@"
}

xorg_info_aux ()
{
  xorg_info_connected | grep -v ' primary '
}

xorg_info_connected () # ~ # List xrandr line of each connected display
{
  xrandr --query | grep ' connected '
}

xorg_info_primary ()
{
  xrandr --query | grep ' connected primary'
}

xorg_names () # ~ # List actual connected display monitors by their link name.
{
  xorg_info_connected | cut -d' ' -f1
}

xorg_screen_dpi ()
{
  test $# -gt 0 || set -- $(xorg_screen_info screens)

  for screen in "$@"
  do xorg_screen_info dpi $screen
  done
}

xorg_font_dpi ()
{
  # See if Xsettings has something about font DPI (maybe not)
  xrdb -query | grep dpi
}

xorg_screen_info () # ~ # Use xdpyinfo to list screen info.
{
  case "${1:-screens}" in
      ( size ) # Report size in pixes, mm and DPI in HxV
            xdpyinfo -display :$2 |
                grep -B1 resolution: |
                grep -o '[0-9][0-9]*x[0-9][0-9]*' | tr -d '\n'
          ;;

      ( dpi ) # Report DPI in HxV
            xdpyinfo -display :$2 |
                grep resolution: |
                grep -o '[0-9][0-9]*x[0-9][0-9]*'
          ;;

      ( screens ) # List Xorg 'display numbers' ie. screens.
            xdpyinfo | grep '^screen #.*:$' | grep -o '[0-9]*'
          ;;
  esac
}

xorg_settings_sh ()
{
  cat <<EOM
xorg__screen__0__dpi	xorg_screen_info dpi 0
xorg__font__dpi
EOM
}
xorg_settings ()
{
  true
}

#
