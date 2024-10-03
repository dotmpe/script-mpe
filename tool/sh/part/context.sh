
#alias context='user-bg at_ ctx'

#alias ctx=context.sh
alias vctx='$EDITOR $(context.sh files all)'

alias context-bg-init='
  user-bg-eval lib_require us-fun sys-htd statusdir todotxt context-uc &&
  user-bg-eval lib_init'

alias context-list='user-bg context_tab'

#
