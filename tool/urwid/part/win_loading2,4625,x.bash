
declare -gA \
x_4625_win_loading2_hooks=(
# -geometry is of no use with i3 docked
#
  [resize]=\
'i3-msg '\''[instance=loading-indicator*] resize set height 26; border pixel 0 '\'

  [start]=\
'i3-msg '\''split v; exec "urxvt -hold -name loading-indicator-a -shading 0 -e bash -c \". ~/bin/.venv/bin/activate && python ~/bin/tool/urwid/x/win_loading2,4625.py\""'\''
sleep .25 && i3-msg '\''[instance=loading-indicator*] resize set height 26; border pixel 0; focus up'\'

)
