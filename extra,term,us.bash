us_term_extra_pre=User-Script.Terminal
us_term_extra_fun=(
  .print-palette-card
  .test-osc
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

User-Script.Terminal.test-osc ()
{
  : about "Test terminal Operation System Commands (OSC) support"
  (($#)) || set -- 4 10 11 12 21
  local osc
  for osc
  do
    printf "\033]$osc;?\007"
    # Example used 1second. 0.01s may be too fast.
    read -rs -d $'\007' -t 0.1 response  # Read until BEL, timeout 0.1s
    if [[ $response =~ ^$'\033]'$osc';rgb:' ]]; then
      echo "OSC $osc supported: ${response@Q}"
    else
      echo "OSC $osc not supported"
    fi
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
    echo "${!fg} $fg $r  ${!bg} $bg $r  ${!dfg} $dfg $r  ${!dbg} $dbg $r"
  done
}

#
