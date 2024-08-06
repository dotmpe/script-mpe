#!/usr/bin/env bash

# Festival voice is "the best", but still very synthetic and sometimes a bit
# hard to follow and understand.
# TODO: Try better voices (Nitech arctic) require Festival 1.95

# I guess order of preference is festival, pico, and then espeak. They are not
# bad, for their purpose. But increasingly robotic and sometimes hard to follow
# on unrestricted domain text.

tts_espeak ()
{
  espeak -vmb-us3 -s 150 -p 45 "$1"
  #espeak -ven -s 150 -p 45 "$1"
}

tts_festival ()
{
  #festival -b '(voice_cmu_us_slt_arctic_hts)' '(SayText "'"$1"'")'
  festival --language american_english -b '(SayText "'"$1"'")'
  #festival --language british_english -b '(SayText "'"$1"'")'
  #festival --language english -b '(SayText "'"$1"'")'
}

tts_pico ()
{
  pico2wave -w=/tmp/test.wav "$1" &&
  aplay /tmp/test.wav &&
  rm /tmp/test.wav
}


while [[ $# -gt 0 ]]
do
  [[ $1 =~ ^[0-9\.]+$ ]] && {
    sleep "$1"
    shift
    continue
  }

  "tts_${tts_engine:-festival}" "$1" || ${us_stat:-exit} $?
  shift
done
#
