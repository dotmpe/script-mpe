#!/usr/bin/env bash
# Source: https://stackoverflow.com/questions/13889659/read-a-file-by-bytes-in-bash

read8 ()
{
  local _r8_var=${1:-OUTBIN} _r8_car LANG=C IFS=
    read -s -r -d '' -n 1 _r8_car
    printf -v $_r8_var %d \'$_r8_car
}
read16 ()
{
  local _r16_var=${1:-OUTBIN} _r16_lb _r16_hb
    read8  _r16_lb && read8  _r16_hb
    printf -v $_r16_var %d $(( _r16_hb<<8 | _r16_lb ))
}
read32 ()
{
  local _r32_var=${1:-OUTBIN} _r32_lw _r32_hw
  read16 _r32_lw && read16 _r32_hw
  printf -v $_r32_var %d $(( _r32_hw<<16| _r32_lw ))
}
read64 ()
{
  local _r64_var=${1:-OUTBIN} _r64_ll _r64_hl
  read32 _r64_ll && read32 _r64_hl
  printf -v $_r64_var %d $(( _r64_hl<<32| _r64_ll ))
}

writebin ()
{
  local i=$[${2:-64}/8] o= v r
    r=$[i-1]
    for ((;i--;)) {
      printf -vv '\%03o' $[($1>>8*(0${3+-1}?i:r-i))&255]
        o+=$v
    }
  printf "$o"
}

#
