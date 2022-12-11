
alias tmux-options='tmux show-options -g'

alias tmux-toggle-autolock='{

  test -z "${tmux_lock_timeout:-}" && {
    tmux_lock_timeout=$(tmux show-option -gv lock-after-time)
    test -n "${tmux_lock_timeout:-}" || return
    tmux set-option -gv lock-after-time 0
    tmux display-message "Autolock timer OFF"
  } || {
    tmux set-option -gv lock-after-time $tmux_lock_timeout
    tmux display-message "Autolock timer at ${tmux_lock_timeout:?} seconds"
  }

}'

#
