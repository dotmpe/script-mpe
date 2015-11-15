period=30
[ -n "$1" ] && period=$1
R6=128x96 
R5=256x192
R4=320x240
#R3=352x288
R2=384x288
R1=640x480

MED=$R2
MAX=$R1
QD1=2
C1=3

C=$C1
QD=$QD1
R=$MAX

#R=480x360 not supported
#R=512x384 not supported

while true
do
  fn=raspb1-$(date +%s).jpg
  echo $fn $R
  #stdout=$(fswebcam --info xrc --title CAM3 --gmt $fn -r $R 2>&1 )
  #stdout=$(fswebcam -q --shadow --bottom-banner --line-colour '#AAEF2929' --banner-colour '#BBCC0000' --gmt $fn -r $R 2>&1 ) # red
  stdout=$(fswebcam -q --title "CAM 1    DESKTOP LAMP" --info "rasbp1  (debian/wheezy)" --shadow --bottom-banner --line-colour '#AA729FCF' --banner-colour '#BB204A87' --gmt $fn -r $R 2>&1 ) # blue
  #stdout=$(fswebcam -q --info "rasbp1 debian/wheezy" --shadow --bottom-banner --line-colour '#AAFCAF3E' --banner-colour '#BBCE5C00' --gmt $fn -r $R 2>&1 ) # orange
  if [ "${stdout:0:7}" = "Corrupt" ] || [ "${stdout:0:7}" = "Prematu" ]
  then
    rm $fn;
    #mv $fn $(basename $fn .jpg)-corrupt.jpg
    if  [ "$R" = "$MAX" ]
    then
      QD=$(( $QD - 1 ))
      if [ "$QD" = "0" ]
      then
        QD=$QD1
        R=$MED
      fi
    fi
    echo Trying again in a second..
    sleep 1
    continue
  else
    #echo $stdout
    #echo $fn
    if [ "$R" = "$MED" ]
    then
      if [ "$C" = "0" ]
      then
        C=$C1
        R=$MAX
      else
        C=$(( $C - 1 ))
      fi
    fi
  fi
  echo -n .
  sleep $period
done
