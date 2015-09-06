
  test -n "$UCONFDIR" || UCONFDIR=$HOME/.conf
  test -n "$BOX_DIR" || {
    BOX_DIR=$UCONFDIR/box
  }
  test -n "$BOX_BIN_DIR" || {
    BOX_BIN_DIR=$UCONFDIR/path/Generic
  }

. $HOME/bin/std.sh

test -z "$BOX_INIT" && BOX_INIT=1 || error "unexpected re-init"
