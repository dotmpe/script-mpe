powerline_pre=Powerline

# Powerline is a subset of "nerd fonts", patched fonts to provide glyphs for
# use in terminals.
declare -gA \
powerline_hooks=(
  [init]=\
'Powerline.init-vars Powerline_glyphs'
  [dump]=\
'test -z \"$(compgen -v -X '\''!POWERLINE_*'\'')\" || declare -p $_'
)

Powerline.init-vars ()
{
  declare -n _glyphmap=${1:?}
  declare glyphcode
  declare -n _descr="_glyphmap[\"\$glyphcode\"]"
  for glyphcode in ${!_glyphmap[@]}
  do
    : "${_descr##*(}"
    : "${_%)*}"
    : "${_//[^A-Za-z0-9]/_}"
    test -n "${_}" || continue
    : "${_^^}"
    printf -v POWERLINE_${_} "\u${glyphcode#U+}"
  done
}

declare -gA \
Powerline_glyphs=(
  [U+E0A0]='	Version control branch symbol	(branch)'
  [U+E0A1]='	Line number symbol	(line number)'
  [U+E0A2]='	Closed padlock symbol	(padlock)'
  [U+E0B0]='	Rightwards black arrowhead	(right solid arrow)'
  [U+E0B1]='	Rightwards arrowhead	(right outline arrow)'
  [U+E0B2]='	Leftwards black arrowhead	(left solid arrow)'
  [U+E0B3]='	Leftwards arrowhead	(left outline arrow)'
)

#    U+E0BA ()
#    U+E0BB ()
#    U+E0BC ()
#    U+E0BD ()
#    U+E0BE ()
#    U+E0BF ()
#    U+E0B8 ()
#    U+E0B9 ()
#    U+E0B4 (offset black circle left)
#    U+E0B5 (offset outline circle left)
#    U+E0B6 (offset black circle right)
#    U+E0B7 ()
#    U+E0A3 (column number)
#    U+E0CA ()
#    U+E0CF (lego ortho)
#    U+E0CE (lego ortho 90)
#    U+E0CD ()
#    U+E0C8 ()
#    U+E0C3 ()
#    U+E0C2 ()
#    U+E0C1 ()
#    U+E0C0 ()
#    U+E0C7 ()
#    U+E0C6 ()
#    U+E0C5 ()
#    U+E0C4 ()
#    U+E0D2 (offset dia sq left)
#    U+E0D0 (lego top)
#    U+E0D1 (lego side 90)
#    U+E0D4 (offset dia sq right)
declare -gA \
Powerline_Extra_glyphs=(
  [E0A3]='(column number)'
  [E0B4]='(offset black circle left)'
  [E0B5]='(offset outline circle left)'
  [E0B6]='(offset black circle right)'
  [E0B7]='()'
  [E0B8]='()'
  [E0B9]='()'
  [E0BA]='()'
  [E0BB]='()'
  [E0BC]='()'
  [E0BD]='()'
  [E0BE]='()'
  [E0BF]='()'
  [E0C0]='()'
  [E0C1]='()'
  [E0C2]='()'
  [E0C3]='()'
  [E0C4]='()'
  [E0C5]='()'
  [E0C6]='()'
  [E0C7]='()'
  [E0C8]='()'
  [E0CA]='()'
  [E0CD]='()'
  [E0CE]='(lego ortho 90)'
  [E0CF]='(lego ortho)'
  [E0D0]='(lego top)'
  [E0D1]='(lego side 90)'
  [E0D2]='(offset dia sq left)'
  [E0D4]='(offset dia sq right)'
)

Powerline.Extra.print-glyph-fill-2 ()
{
  local -a glyphcodes=( "$@" )
  local c r
  for ((r=0; r<20; r++))
  do
    for ((c=0; c<40; c++))
    do
      (( r % 2 )) && {
        (( c % 2 )) &&
        printf "\u${glyphcodes[1]#U+}" ||
        printf "\u${glyphcodes[0]#U+}"
      } || {
        ! (( c % 2 )) &&
        printf "\u${glyphcodes[1]#U+}" ||
        printf "\u${glyphcodes[0]#U+}"
      }
    done
    echo
  done
  echo
}

Powerline.Extra.print-glyph-fill-3 ()
{
  local -a glyphcodes=( "$@" )
  local c r
  for ((r=0; r<20; r++))
  do
    printf "%$((20-r))s" " "
    for ((c=0; c<10; c++))
    do
      for glyphcode in ${glyphcodes[@]}
      do
        printf "\u${glyphcode#U+}"
      done
    done
    echo
  done
  echo
}

Powerline.Extra.print-glyph-fill ()
{
  local -a glyphcodes=( "$@" )
  local c r
  for ((r=0; r<20; r++))
  do
    for ((c=0; c<40; c++))
    do
      for glyphcode in ${glyphcodes[@]}
      do
        printf "\u${glyphcode#U+}"
      done
    done
    echo
  done
  echo
}

Powerline.Extra.print-glyph-listing ()
{
  declare -n _glyphmap=${1:?}
  declare glyphcode
  declare -n _descr="_glyphmap[\"\$glyphcode\"]"
  for glyphcode in ${!_glyphmap[@]}
  do
    printf "  \u${glyphcode#U+}  U+${glyphcode#U+} %s\n" "${_descr}"
  done
}
