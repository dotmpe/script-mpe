#!/usr/bin/env bash

# TODO: there are lots of small legible figlet fonts at three lines high

# TODO: have a look at toilet for proper ANSI colored setup?

set -euo pipefail

: "${OS_UNAME:=$(uname -s)}"

case "${OS_UNAME:?}" in

  Darwin )
      esc=`echo '\033'`
    ;;

  Linux | CYGWIN_NT-6.1 )
      # For GNU sed: \o033
      esc=`echo -e '\o33'`

      case "$(sed --version)" in *"This is not GNU sed"* )
              # For matchbox sed
              esc=`echo -e '\033'`
          ;;
      esac
    ;;

  * ) error "No stdio-type for $OS_UNAME" 1 ;;
esac


# Default is: /usr/share/figlet but some setups add 'fonts' subdir
true "${FIGLET_FONTS_DIR:=$(figlet -I 2)}"

# XXX: pyfiglet uses its own font dir and not sure how to override

declare -a FONTSET=(
"3d"
"Alligator"
"Alligator2"
"Alpha"
"AMC Razor2"
"ANSI Regular"
"ANSI Shadow"
"Basic"
"Big"
"Calvin S"
"Chunky"
"cosmic"
"Cyberlarge"
"Cybermedium"
"Cybersmall"
"Delta Corps Priest 1"
Electronic
Elite
Fender
"Four Tops"
Graffiti
Isometric1
Isometric2
Isometric3
Isometric4
"JS Stick Letters"
Lean
LCD
miniwi
Muzzle
O8
Pepper
Poison
"Red Phoenix"
Relief
Relief2
Reverse
Roman
Rounded
Rozzo
"S Blood"
Shadow
Small
"Small Caps"
"Small Isometric1"
Standard
"Stronger Than All"
Test1
threepoint
Univers
Whimsy
)

true "${COLS:=$(tput cols)}"


case "$1" in

    graffiti ) f=$1 ; shift
            figlet -w "$COLS" -kf $f "$@" | sed -E '
    s/[<>Y()]/'$esc'[1;36m&'$esc'[0m/g
    s/[\/_]/'$esc'[1;30m&'$esc'[0m/g
    s/[\|\\]/'$esc'[0;36m&'$esc'[0m/g
    s/[\.]/'$esc'[1;37m&'$esc'[0m/g '
        ;;

    alligator | alligator2 ) f=$1 ; shift
            figlet -w "$COLS" -kf $f "$@" | sed -E '
    s/:/'$esc'[1;36m&'$esc'[0m/g
    s/\+/'$esc'[1;32m&'$esc'[0m/g
    s/\#/'$esc'[1;33m&'$esc'[0m/g '
        ;;

    sblood | poison ) f=$1 ; shift
            figlet -w "$COLS" -f $f "$@" | sed -E '
    s/@/'$esc'[1;31m@'$esc'[0m/g
    s/!/'$esc'[0;31m!'$esc'[0m/g
    s/[.:]/'$esc'[0;35m&'$esc'[0m/g
  '
        ;;

    chunky ) shift
            figlet -w "$COLS" -f chunky "$@" | sed -E '

    s/_/'$esc'[0;31m_'$esc'[0m/g
    s/\//'$esc'[0;33m\/'$esc'[0m/g
    s/\\/'$esc'[0;34m\\'$esc'[0m/g
    s/~/'$esc'[0;35m\~'$esc'[0m/g
    s/\|\|/'$esc'[0;35m\|'$esc'[0m\|/g
    s/\|/'$esc'[1;31m\|'$esc'[0m/g
    s/-/'$esc'[1;31m-'$esc'[0m/g
  '
        ;;

    relief ) shift
            figlet -w "$COLS" -f relief "$@" | sed -E '
    s/_/'$esc'[1;30m_'$esc'[0m/g
    s/\//'$esc'[0;32m\/'$esc'[0m/g
    s/\\/'$esc'[0;34m\\'$esc'[0m/g
    s/~/'$esc'[0;37m\~'$esc'[0m/g
  '
        ;;

    list )
          ( cd "${FIGLET_FONTS_DIR:?}" && ls *.flf | sed 's/\.flf$//g' )
        ;;

    colorize-1 )
          shift
          for font in \
            alligator alligator2 \
            calvins \
            chunky \
            elite \
            graffiti \
            o8 \
            sblood poison \
            relief \
            rozzo \
            miniwi

          do
            "$0" $font "${@:-$font}"
          done
        ;;

    show )
        shift
        "$0" list | while IFS=$'\t\n' read -r fontname
        do
          echo "Font '$fontname':"
          figlet -w "$COLS" -f "$fontname" "${@:-$fontname}"
          echo "-------------------------------------------------------------"
        done
      ;;

    install )
        shift
        test $# -gt 0 || set -- "${FONTSET[@]:?}"
	      test -w "${FIGLET_FONTS_DIR:?}" || pref="sudo "
	      for fontname in "${@:?}"
        do
          filename=${fontname,,}
          filename=${filename// }

          test -e "$FIGLET_FONTS_DIR/${filename:?}" || {
            ${pref:-}wget -nv \
            "https://github.com/xero/figlet-fonts/raw/master/$fontname.flf" \
            -O "$FIGLET_FONTS_DIR/${filename}.flf" || exit $?
          }
          echo "Font '$fontname' OK"
        done
	    ;;


    * )
            figlet -w "$COLS" -f "$@" | sed -E '
    s/[^ ]/'$esc'[0;32m&'$esc'[0m/g
  '
        ;;

esac
