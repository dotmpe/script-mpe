declare -gA \
x_4625_win_loading2_hooks=(

# rxvt instances: xprop reports minimum size of 12x28, but it works out to from
# around 39 (minimum settable height via i3 resize IPC) to 50 (reported by
# get_tree IPC). So thats is a bit too clunky for the intended purpose (a sleek
# loading bar stretching the screen's edge), but it is an interesting
# experiment.

# What is nice though, URxvt's pseudo transparency can just show the desktop
# wallpaper everywhere there is no background / no other glyphs are rendered.

  [resize]=\
'i3-msg '\''[instance=loading-indicator*] resize set height 26; border pixel 0 '\'

  [start]=\
'i3-msg '\''[instance=loading-indicator*] resize set height 26; border pixel 0; focus up'\'' &&
i3-msg '\''split v; exec "urxvt -hold -name loading-indicator-a -shading 0 -e bash -c \". ${VIRTUAL_ENV_BASEDIR:?}/${PY_VENV_NAME:-script-mpe-pyvenv}/bin/activate && python ~/bin/tool/urwid/x/win_loading2,4625.py\""'\'

)
