#!/bin/bash
#
# dec-linedraw.sh
# Copyright (C) 2026 qwrt <qwrt@t460s>
#
# Distributed under terms of the MIT license.
#
PUT(){ echo -en "\033[${1};${2}H";}
DRAW(){ echo -en "\033%";echo -en "\033(0";}
# echo -en "\033(0"  # Enter line drawing
# echo -en "\033%"  # Select default/UTF-8 mode (compatibility, not required for
# line drawing)
WRITE(){ echo -en "\033(B";}
HIDECURSOR(){ echo -en "\033[?25l";}
NORM(){ echo -en "\033[?12l\033[?25h";}

#clear
#HIDECURSOR
DRAW  # Enter line drawing mode
for i in {a..z} {0..9} {A..Z} @; do
  echo -en "$i "
done
WRITE  # Back to normal
#NORM
