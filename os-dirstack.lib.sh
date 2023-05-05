# FIXME: can Bourne Sh do pushd/popd in a function?
#cmd_exists pushd || {
#pushd()
#{
#  tmp=/tmp/pushd-$$
#  echo "pushd \$\$=$$ $@"
#  echo "$1" >>$tmp
#  cd $1
#}
#popd()
#{
#  tmp=/tmp/pushd-$$
#  echo "popd \$\$=$$ $@"
#  tail -n 1 $tmp
#  cd $(truncate_trailing_lines $tmp 1)
#}
#}
#
#pushd_cwdir()
#{
#  test -n "$CWDIR" -a "$CWDIR" != "$PWD" && {
#    echo "pushd $CWDIR" "$PWD"
#    pushd $WDIR
#  } || set --
#}
#
#popd_cwdir()
#{
#  test -n "$CWDIR" -a "$CWDIR" = "$PWD" && {
#    echo "popd $CWDIR" "$PWD"
#    test "$(popd)" = "$CWDIR"
#  } || set --
#}
