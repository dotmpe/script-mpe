#!/bin/sh

### Library for interrogating Xorg system.

#shellcheck disable=SC2046 # Quote to prevent word splitting.
#shellcheck disable=SC2086 # Double quote to prevent globbing and word splitting.

xorg_lib_depends="os* "
xorg_lib_settings=xorg_settings_sh

: "${BOX_HWDIR:="$HOME/.local/box/$(hostname -s)"}"
: "${XRANDR_INFO_DOC:="${BOX_HWDIR}/xrandr-verbose.out"}"
: "${XRANDR_INFO_FKV:="${BOX_HWDIR}/xrandr-verbose.fkv"}"

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
  xorg_display_info "$@" |
      sed 's/ (.*)//
        s/+/ /g
        s/\([0-9]\)x\([0-9]\)/\1 \2/
        s/\([0-9]\)mm/\1/g' |
      while read name x_px y_px _ _ w_mm _ h_mm
      do
        width_inch=$(echo "scale=3; $w_mm / 25.4" | bc)
        height_inch=$(echo "scale=3; $h_mm / 25.4" | bc)
        dpi_h=$(echo "scale=0; $x_px / $width_inch" | bc)
        dpi_v=$(echo "scale=0; $y_px / $height_inch" | bc)

        echo "$name $w_mm $h_mm $dpi_h $dpi_v"
      done
}

# Read monitor size from EDID and calculate DPI.
# Neither Xorg nor monitor EDID always provides correct panel size.
xrandr_dpi ()
{
  xrandr_display_info_flags= xrandr_display_info "$@" | while read \
      link id edid_v mfd w_mm h_mm gamma dpms hsync vr pc w_px h_px dx_px dy_px
  do
    test -e "$BOX_HWDIR/monitor/$id.size" && {
      read w_mm h_mm < "$BOX_HWDIR/monitor/$id.size"
    }
    width_inch=$(echo "scale=3; $w_mm / 25.4" | bc)
    height_inch=$(echo "scale=3; $h_mm / 25.4" | bc)
    dpi_h=$(echo "scale=0; $w_px / $width_inch" | bc)
    dpi_v=$(echo "scale=0; $h_px / $height_inch" | bc)

    echo "$link $id $w_mm $h_mm $dpi_h $dpi_v"
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

# This gives the side/dpi or the entire desktop (which may cover multiple
# outputs)
xorg_screen_info () # ~ (screens|size|dpi) [DISPLAY] # Use xdpyinfo to list screen info.
{
  case "${1:-screens}" in
    ( dpi ) # Report DPI in HxV
        xdpyinfo -display :$2 |
            grep resolution: |
            grep -o '[0-9][0-9]*x[0-9][0-9]*'
      ;;

    ( dump )
        pyrandr.py ls | jq .
      ;;

    ( extensions-info )
        xdpyinfo -ext all
      ;;

    ( screens ) # List Xorg 'display numbers' ie. screens.
        xdpyinfo | grep '^screen #.*:$' | grep -o '[0-9]*'
      ;;

    ( size ) # Report size in pixes, mm and DPI in HxV
        echo $(xdpyinfo -display :$2 |
            grep -B1 resolution: |
            grep -o '[0-9][0-9]*x[0-9][0-9]*')
      ;;

    ( * ) return 99 ;;
  esac
}

# Go over Xorg outputs, and get a name for each monitor by reading the EDID.
# Leave name,EDID,Xorg files in $BOX_HWDIR/monitor/<monitor-id>* and link
# to monitor/<monitor-id> from BOX_HWDIR/display-<link-name>.
xrandr_build_info ()
{
  test -e "$XRANDR_INFO_DOC" || xrandr --verbose >"$XRANDR_INFO_DOC"

  test -d "$BOX_HWDIR" || mkdir -p "$BOX_HWDIR"

  test -e "$XRANDR_INFO_FKV" -a "$XRANDR_INFO_FKV" -nt "$XRANDR_INFO_DOC" || {
    pyrandr.py ls "$XRANDR_INFO_DOC" | jsotk to-flat-kv |
        cut -c4- > "$XRANDR_INFO_FKV"
  }

  xrandr_monitor_name ()
  {
    monitor_name="$VendorName"
    monitor_name="$(str_concat "$monitor_name" "$ModelName")"
    test "$ModelName" = "$Identifier" ||
        monitor_name="$(str_concat "$monitor_name" "$Identifier")"
  }

  for name in $(xorg_names)
  do
    key=$(echo "$name" | tr '-' '_')

    test -e "$BOX_HWDIR/display-$name" && continue


    eval $( grep '^'"$key"'_' "$XRANDR_INFO_FKV" | sed 's/^'"$key"'_//' )
    echo "$EDID" | xxd -r -p \
        > "$BOX_HWDIR/monitor/$name.edid"

    eval "$( parse-edid < "$BOX_HWDIR/monitor/$name.edid" | xrandr_kv )"
    xrandr_monitor_name
    mkid "$monitor_name"

    echo "$monitor_name" > "$BOX_HWDIR/monitor/$id"
    ln -s "monitor/$id" "$BOX_HWDIR/display-$name"

    mv "$BOX_HWDIR/monitor/$name.edid" "$BOX_HWDIR/monitor/$id.edid"

    parse-edid \
        < "$BOX_HWDIR/monitor/$id.edid" \
        > "$BOX_HWDIR/monitor/$id.xorg"
  done
}

# List Xorg config blocks for each monitor from xrandr --verbose
xrandr_edid ()
{
  perl -ne '
      if ((/EDID(_DATA)?:/.../:/) && !/:/) {
        s/^\s+//;
        chomp;
        $hex .= $_;
      } elsif ($hex) {
        # Use "|strings" if you dont have read-edid package installed
        # and just want to see (or grep) the human-readable parts.
        open FH, "|parse-edid";
        print FH pack("H*", $hex);
        $hex = "";
      }'
}

# Combine Xrandr/EDID data to Xorg line, so we can discard the Xorg reported monitor size.
xrandr_display_info ()
{
  fun_flags xrandr_display_info y

  test $xrandr_display_info_y -ne 1 ||
      echo "# Link, Monitor Id, EDID version, Mfd, Width (mm), Height, Gamma,"\
" DPMS, H-sync, V-refresh, Max-Pixel-Clock, Width (px), Height, H-Offset,"\
" Y-Offset"

  xorg_display_info "$@" | sed '
        s/+/ /g
        s/\([0-9]\)x\([0-9]\)/\1 \2/
     ' | while read link w h dx dy _
     do
       echo $(xrandr_info_flags= xrandr_info "$link") $w $h $dx $dy
     done
}

# Print all data from EDID beside Xorg output link name. See xrandr-build-info.
xrandr_info () # ~ <Display-Names...>
{
  test $# -gt 0 || set -- $(xorg_names)
  fun_flags xrandr_info y

  test $xrandr_info_y -ne 1 ||
      echo "# Link, Monitor Id, EDID version, Mfd, Width (mm), Height, Gamma,"\
" DPMS, H-sync, V-refresh, Max-Pixel-Clock"

  for name in "$@"
  do
    test -e "$BOX_HWDIR/display-$name" || {
      echo "Missing display '$name' <$BOX_HWDIR>" >&2
      continue
    }

    monitor_link=$(readlink "$BOX_HWDIR/display-$name")
    monitor_id=$(basename "$monitor_link")
    monitor_name=$(cat "$BOX_HWDIR/$monitor_link")

    eval $(xrandr_kv < "$BOX_HWDIR/$monitor_link.xorg")

    mfd=$(echo "$EDID_Mfd" | sed -E \ '
            s/^week 0 of ([0-9]+)$/\1/
            s/^week ([0-9]+) of ([0-9]+)$/\2w\1/
        ')

    echo "$name $monitor_id $EDID_Version $mfd $DisplaySize $Gamma $DPMS"\
" ${Horizsync:--} ${VertRefresh:--} ${Max_Pixel_Clock:--}"
  done
}

# Reformat anything interesting (except modelines and options other than DPMS)
# from xorg monitor config block.
xrandr_kv ()
{
  sed '
          s/^\t# Monitor Manufactured \(.*\)$/EDID_Mfd="\1"/
          s/^\t# EDID version \(.*\)$/EDID_Version="\1"/
          s/^\t# Maximum pixel clock is \(.*\)$/Max_Pixel_Clock="\1"/
          s/^\t\(Identifier\|ModelName\|VendorName\|Gamma\|Horizsync\|VertRefresh\)\ /\1=/
          s/^\tDisplaySize \(.*\)$/DisplaySize="\1"/
          s/^\tOption "DPMS" /DPMS=/
    ' | grep '='
}

#
