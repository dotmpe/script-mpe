#!/bin/bash
#
# run as pi user, setup for webcam
#
# See /etc/rc.local

DISK=/mnt/flash


bash <<SCREEN_INIT

[ ! -e "$DISK/.volume/" ] && {
  echo "Missing flash volume, disk not mounted. "
  exit 1;
}

[ ! -e "$DISK/webcam/" ] && {
  mkdir $DISK/webcam
}

cd $DISK/webcam
screen -dmS WebCam

sleep 1
screen -S WebCam -p 0 -X stuff "/opt/raspberry-pi/timelapse.sh 60"$(echo -ne '\r')

SCREEN_INIT
