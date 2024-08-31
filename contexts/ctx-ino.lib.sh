#!/bin/sh

ctx_ino_lib__init()
{
  test ${ctx_ino_lib_init:-1} -eq 0 && return
  local ino="$(which arduino)"
  test -x "$ino" || {
      $LOG error "" "No Arduino exec found" "$ino" 1 ;
      return
  }
  case "$ino" in

    /snap/bin/* ) true "${ARDUINODIR:="/snap/arduino/current"}" ;;
    /usr/bin/* ) true "${ARDUINODIR:="/usr/share/arduino"}" ;;

    /Applications/Arduino.app/* ) # | $HOME/Applications/Arduino.app/* )
        true "${ARDUINODIR:="/Applications/Arduino.app/Contents/Resources/Java"}" ;;

    * ) $LOG warn "" "Unknown Arduino dir" "$ino" ;;
  esac
  ! sys_debug -dev -debug -init ||
    $LOG notice "" "Initialized ctx-ino.lib" "$(sys_debug_tag)"
}

ino_boards_get_field()
{
  {
    grep "^$1.$2" $boards || return
  } | sed 's/^'"$1"'.'"$2"'=//'
}

at_Ino__boards()
{
  local nameid boards=$ARDUINODIR/hardware/arduino/avr/boards.txt
  test -e "$boards" || boards=$ARDUINODIR/hardware/arduino/boards.txt
  {
    echo ID NameID MCU CPU Bootloader Protocol Speed
    for nameid in $(grep -o '^\(.*\)\.name=' $boards | sed 's/.name=.*$//g')
    do
        echo $nameid \
            $(str_word "$(ino_boards_get_field $nameid name)") \
            $(ino_boards_get_field $nameid build.mcu || echo '-') \
            $(ino_boards_get_field $nameid build.f_cpu || echo '-') \
            $(ino_boards_get_field $nameid bootloader.file || echo '-') \
            $(ino_boards_get_field $nameid upload.protocol || echo '-') \
            $(ino_boards_get_field $nameid upload.speed || echo '-')
    done
  } | { test -t 1 && column -tcx || cat -; }

  # Makefiles only lists ID's and names.
  #cd ~/project/arduino-docs
  ##make boards OLD=1
  #make -f arduino.mk boards
}
