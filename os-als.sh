#test ${_E_sigpipe:-141} -eq $? && continue
alias os-als:loop-stat1='{
  test "$?"
  test ${_E_retry:?} -eq $_ && continue
  test ${_E_break:?} -eq $_ && return $_
  test ${_E_next:?} -eq $_ || return $_
}'

#
