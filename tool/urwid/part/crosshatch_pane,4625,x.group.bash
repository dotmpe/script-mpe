declare -gA \
x_4625_crosshatch_pane_hooks=(

  [start-inline]=\
'bash -c ". ${VIRTUAL_ENV_BASEDIR:?}/${PY_VENV_NAME:-script-mpe-pyvenv}/bin/activate &&
python ~/bin/tool/urwid/x/crosshatch_pane,4625.py --simple crosshatch"'

  [start-float]=\
'i3-msg '\''exec "urxvt -hold -name crosshatch-pane-a -e bash -c \". ${VIRTUAL_ENV_BASEDIR:?}/${PY_VENV_NAME:-script-mpe-pyvenv}/bin/activate && python ~/bin/tool/urwid/x/crosshatch_pane,4625.py --simple crosshatch\""'\''
sleep .25 && i3-msg '\''[instance=crosshatch-pane-a] floating toggle; resize set width 500 height 500; border pixel 10'\'

#  [start-pane]=\
#'i3-msg '\''split v; exec "urxvt -hold -name loading-indicator-a -shading 0 -e bash -c \". ~/bin/.venv/bin/activate && python ~/bin/tool/urwid/x/win_loading2,4625.py\""'\''
#sleep .25 && i3-msg '\''[instance=loading-indicator*] resize set height 26; border pixel 0; focus up'\'

)
