(
  cd "$REDO_BASE" &&
      bats \
        test/main-spec.bats \
        test/util-lib-spec.bats
)
