#!/usr/bin/env bash
# vol-osd – volume control + XOSD feedback (pamixer + osd_cat)

FONT="-*-fixed-*-*-*-*-*-240-*-*-*-*-*-*"
COLOR="#LawnGreen"
MUTECOLOR="red"

#FONT='-*-terminus-*-*-*-*-*-280-*-*-*-*-*-*'
FONT='-*-terminus-bold-r-*-*-48-*-*-*-*-*-*-*'
COLOR="#4fd5a9"
MUTECOLOR="#d54f53"

STEP=5          # volume step in %
POS="middle"    # top | middle | bottom
DELAY=1.5
OVERLAP=0.1
BORDER=4

vol_osd ()
{
	# Get current state
	VOL=$(pamixer --get-volume)
	MUTED=$(pamixer --get-mute)

	# Kill previous OSD so rapid knob turns don’t stack
	#killall -q osd_cat 2>/dev/null
	pid=$(pgrep osd_cat)

	if [ "$MUTED" = "true" ]; then
			osd_cat \
					--outline=$BORDER \
					--font="$FONT" \
					--color="$MUTECOLOR" \
					--pos="$POS" \
					--align=center \
					--delay="$DELAY" \
					--barmode=percentage \
					--percentage=0 \
					--text="Muted" &
	else
			osd_cat \
					--outline=$BORDER \
					--font="$FONT" \
					--color="$COLOR" \
					--pos="$POS" \
					--align=center \
					--delay="$DELAY" \
					--barmode=percentage \
					--percentage="$VOL" \
					--text="Volume: ${VOL}%" &
	fi

	# This prevents flashes cq blanking between OSD updates
	# XXX: there may be a better way to feed osd_cat data, this is based on
  # what AI came up with
	if [[ ${pid:+set} ]]; then sleep $OVERLAP; kill -9 $pid; fi
}

case "$1" in
( show )
		vol_osd
	;;
( up )
		pamixer --allow-boost -i "${2:-$STEP}"
		vol_osd
	;;
( down )
		pamixer --allow-boost -d "${2:-$STEP}"
		vol_osd
	;;
( mute )
		pamixer -t
		vol_osd
	;;
( * )
		echo "Usage: $0 {show|up|down|mute}"
		exit 1
	;;
esac
