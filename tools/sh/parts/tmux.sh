
# Show all global options currently set
alias tmux-options='tmux show-options -g'

# Show normal mode keys
alias tmux-keys-normal='tmux list-keys -T root'

# Show prefix and copy mode keys
alias tmux-keys-prefix='tmux list-keys -T prefix'
alias tmux-keys-copy='tmux list-keys -T copy-mode && tmux list-keys -T copy-mode-vi'


# Key bindings are normally listed with <Prefix> ?

alias tmux-set-autolock='tmux set-option -g lock-after-time' # <Seconds>

# Turn visual lock on/off
alias tmux-toggle-autolock='{

  test -z "${tmux_lock_timeout:-}" && {
    tmux_lock_timeout=$(tmux show-option -gv lock-after-time)
    test -n "${tmux_lock_timeout:-}" || return
    tmux set-option -g lock-after-time 0
    tmux display-message "Autolock timer OFF"
  } || {
    tmux set-option -g lock-after-time $tmux_lock_timeout
    tmux display-message "Autolock timer at ${tmux_lock_timeout:?} seconds"
    unset tmux_lock_timeout
  }

}'

#
