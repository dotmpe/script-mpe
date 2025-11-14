us_term_extra_pre=User-Script.Terminal
us_term_extra_fun=(
  .cursor-position
  .print-palette-card
  .test-osc
  .test-color-capabilities
  .test-palettes
  .test16
)
declare -gA \
us_term_extra_als=(
  [.print-osc-p]='printf "\e]P%01X%s%s%s"'
  [.print-osc-4]='printf "\x1b]4;%d;rgb:%s/%s/%s\a"'
  [.print-osc-10]='printf "\x1b]10;rgb:%s/%s/%s\a"' # foreground
  [.print-osc-11]='printf "\x1b]11;rgb:%s/%s/%s\a"' # background
  [.print-osc-12]='printf "\x1b]12;%d\a"' # cursor (colorindex)
  [.print-osc-21]='printf "\x1b]21;cursor=%s\a"' # cursor RGB
)
declare -gA \
us_term_extra_ssc=(
  [.test-terminal]=\
'User-Script.Terminal.test-osc && User-Script.Terminal.test-color-capabilities'
)

User-Script.Terminal.cursor-position ()
{
  : input "${1:?$FUNCNAME${*:+ $*}:Column variable}"
  : input "${2:?$FUNCNAME${*:+ $*}:Row variable}"
  local -n _ust_cp_col=${1} _ust_cp_row=${2}
  printf '\e[6n'
  read -sdR pos || return
  pos="${pos#*\[}"
  _ust_cp_row="${pos%;*}"
  _ust_cp_col="${pos#*;}"
}

User-Script.Terminal.print-palette-card ()
{
  local labels=1 swcol=9 swln=2 splitrow=0
  while (($#)) && case "${1-}" in
     ( --no-labels ) labels=0
  ;; ( --swatch-size ) read -r sw{col,ln} <<< "${2/[x,.:]/ }"; shift
  ;; ( --swatch-cols ) swcol=${2:?}; shift
  ;; ( --swatch-lines ) swln=${2:?}; shift
  ;; ( --splitrow ) splitrow=1 # Divide into two rows
  ;; * ) false
    esac
  do shift
  done || return ${_E_GAE:?}

  local -a card
  local i=0 lbl _r _g _b _name{,s} w=$((swcol-1)) c
  while read -r _r _g _b _names
  do
    [[ $i -eq 16 ]] && lbl=fg || {
      [[ $i -eq 17 ]] && lbl=bg || lbl=$i
    }
    c=$( printf "\x1b[48;2;%d;%d;%dm %${w}s\x1b[0m\n" 0x$_r 0x$_g 0x$_b $lbl
      ((swln-=1))
      until ! ((swln))
      do
        printf "\x1b[48;2;%d;%d;%dm %${w}s\x1b[0m\n" 0x$_r 0x$_g 0x$_b ""
        ((swln-=1))
      done)
    card+=( "$c" )
    ((i+=1))
  done

  local -a outlines
  local outln=0 _ln rowlen
  ((splitrow)) && rowlen=$(( ${#card[@]} / 2 ))
  for j in "${!card[@]}"
  do
    _ln=$outln
    while read -r ln
    do
      outlines[_ln]=${outlines[_ln]:+${outlines[_ln]} }${ln}
      ((_ln+=1))
    done <<< "${card[j]}"
    ! ((rowlen)) || [[ $rowlen -ne $((j+1)) ]] || ((outln+=$swln))
  done

  printf '%s\n' "${outlines[@]}"
}

User-Script.Terminal.test-color-capabilities ()
{
  local cap
  for cap in initc set{,a}{f,b}
  do
    if_ok "$(tput $cap)" &&
    test -n "$_" &&
    echo "Terminal $cap supported: ${_@Q}" ||
    echo "Fail: $cap not supported"
  done
}

User-Script.Terminal.test-osc ()
{
  : about "Test terminal's Operation System Commands (OSC) support"
  (($#)) || set -- 4 10 11 12 21
  local osc
  for osc
  do
    printf "\033]$osc;?\007"
    # Example used 1 second. 0.01s may be too fast.
    read -rs -d $'\007' -t 0.1 response &&  # Read until BEL, timeout 0.1s
    [[ $response =~ ^$'\033]'$osc';rgb:' ]] &&
      echo "OSC $osc supported: ${response@Q}" ||
      echo "Fail: OSC $osc not supported"
  done
}

User-Script.Terminal.test-palettes ()
{
  (($#)) || set -- ${us_palette_var[@]:?}
  local -n _palette
  local line
  for _palette
  do
    if_ok "$(<<< "${_palette:?$FUNCNAME:$1: Palette table value, $ENV_CTX}" \
      User-Script.Terminal.print-palette-card --swatch-size 5x2)"
    #--splitrow
    echo "$_  ${!_palette}"
    echo
  done
}

User-Script.Terminal.test16 ()
{
  local r=$RESET {,d}{f,b}g i
  for i in {0..7}
  do
    fg=_f$i
    bg=_b$i
    dfg=_f$((i+8))
    dbg=_b$((i+8))
    printf "${!fg} %4s $r ${!dfg} %4s $r  ${!bg} %4s $r ${!dbg} %4s $r\n" \
     $fg $dfg $bg $dbg
  done
}

#
