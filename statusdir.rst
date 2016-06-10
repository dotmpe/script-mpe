


statusdir.sh

  @test "statusdir.sh help"
    - run $BATS_TEST_DESCRIPTION
    - test ${status} -eq 0
    - fnmatch "*statusdir <cmd> *" "${lines[*]}"


  sd root
  sd assert-state


