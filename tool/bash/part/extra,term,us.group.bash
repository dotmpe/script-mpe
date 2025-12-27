us_term_extra_pre=User-Script.Terminal.x
us_term_extra_cnk=85bc5cc3
us_term_extra_fun=(
  .device-attributes
  .get-longname
  .print-palette-card
  .raw-query
  .terminal-info
  .test-osc
  .test-color-capabilities
  .test-palettes
  .test-16color
)
declare -gA \
us_term_extra_als=(
  # For OSC [Operating System Command] format see ECMA-48, but commands are
  # implementation defined and de facto standards set by Xterm (not covered by
  # ECMA, ISO/IEC 6429 or ANSI X3.64).
  [.print-osc-p]='printf "\e]P%01X%s%s%s"' # Linux palette (console_codes(4) man page)
  [.print-osc-4]='printf "\x1b]4;%d;rgb:%s/%s/%s\a"' # dynamic color palette
  [.print-osc-10]='printf "\x1b]10;rgb:%s/%s/%s\a"' # foreground
  [.print-osc-11]='printf "\x1b]11;rgb:%s/%s/%s\a"' # background
  [.print-osc-12]='printf "\x1b]12;%d\a"' # cursor (colorindex)
  [.print-osc-21]='printf "\x1b]21;cursor=%s\a"' # window properties: cursor RGB
)
declare -gA \
us_term_extra_ssc=(
  [.test-terminal]=\
'[[ ! -t 1 ]] || {
  User-Script.Terminal.x.test-osc &&
  User-Script.Terminal.x.test-color-capabilities &&
  User-Script.Terminal.x.terminal-info
}'
)

User-Script.Terminal.x.device-attributes ()
{
  : input "${1:?$FUNCNAME${*:+ $*}:Attributes variable (primary)}"
  : input "${2:?$FUNCNAME${*:+ $*}:Attributes variable (secondary)}"
  local -n _ust_da_pa=${1} _ust_da_sa=${2}
  User-Script.Terminal.x.raw-query '\e[c' c _ust_da_pa &&
  User-Script.Terminal.x.raw-query '\e[>c' c _ust_da_sa
}

User-Script.Terminal.x.get-longname ()
{
  : input "${1:?$FUNCNAME${*:+ $*}:Longname variable}"
  local -n _ust_gl_dest=${1}
  if_ok "$(tput longname)" &&
  _ust_gl_dest=$_
}

User-Script.Terminal.x.print-palette-card ()
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

User-Script.Terminal.x.raw-query ()
{
  : input "${1:?$FUNCNAME${*:+ $*}:Query}"
  : input "${2:?$FUNCNAME${*:+ $*}:Scan}"
  : input "${3:?$FUNCNAME${*:+ $*}:Response variable}"
  local _query=${1} _saved_stty _char
  local -n _response=${3}
  _saved_stty=$(stty -g)
  stty raw -echo min 0 time 1
  printf "${_query}"
  _response=''
  while IFS= read -r -n 1 _char; do
    _response+=$_char
    [[ $_char == "$2" ]] && break
  done
  stty "${_saved_stty}"
}

User-Script.Terminal.x.terminal-info ()
{
  local _vte_{pid,cmd,tty{,_attr}}
  User-Script.OS.x.parent-process "" "" _vte_{pid,cmd} &&
  _vte_tty=$(tty) &&
  _vte_tty_attr=$(stty -a) &&
  declare -p TERM _vte_{pid,cmd,tty{,_attr}}
  [[ ! -t 1 ]] || {
    local _vte_{name,{p,s}devatr}
    User-Script.Terminal.x.get-longname _vte_name &&
    User-Script.Terminal.x.device-attributes _vte_{p,s}devatr
    declare -p TERM _vte_{name,{p,s}devatr}
  }
}

User-Script.Terminal.x.test-color-capabilities ()
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

User-Script.Terminal.x.test-osc ()
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

User-Script.Terminal.x.test-palettes ()
{
  (($#)) || set -- ${us_palette_var[@]:?}
  local -n _palette
  local line
  for _palette
  do
    if_ok "$(<<< "${_palette:?$FUNCNAME:$1: Palette table value, $ENV_CTX}" \
      User-Script.Terminal.x.print-palette-card --swatch-size 5x2)"
    #--splitrow
    echo "$_  ${!_palette}"
    echo
  done
}

User-Script.Terminal.x.test-16color ()
{
  local r=$RESET {,d}{f,b}g i _{b,f}g
  # echo "Terminal color palette dim and bright columns for normal and bold"
  echo "${BOLD}${_f15} Normal                          Bold ${r}"
  echo "${BOLD}${_f15} Dim   Bright                    Dim   Bright${r}"
  for i in {0..7}
  do
    fg=_f$i
    bg=_b$i
    dfg=_f$((i+8))
    dbg=_b$((i+8))
    #[[ $i != 0 ]] && _bg= || _bg="${_b7}"
    _bg=
    [[ $i != 7 ]] && _fg= || _fg="${_f0}"
    printf "${!fg}${_bg} %4s $r ${!dfg}${_bg} %4s $r  ${!bg}${_fg} %4s $r ${!dbg}${_fg} %4s $r    " \
     $fg $dfg $bg $dbg
    # Display if terminal supports bold
    [[ $TERM == linux* ]] && echo ||
    printf "${BOLD}${!fg}${_bg} %4s $r ${BOLD}${!dfg}${_bg} %4s $r  ${BOLD}${!bg}${_fg} %4s $r ${BOLD}${!dbg}${_fg} %4s $r\n" \
     $fg $dfg $bg $dbg
  done
}

#
