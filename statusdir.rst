.. include:: .default.rst

Statusdir - lightweight wrapper for key-value storage
=====================================================


Design
-------
- Regular string storage with some profiles of encoding and byte-safety.
- Numeric values. Incremented.
- TODO: manage volatility. Insist on clean indices.
- Some JSOTK (json/yaml) support maybe, for fallback where above fails with a
  backend. Or for layering more complex indices.


::

  sd_be=redis statusdir.sh be flushall

----

statusdir.sh

  @test "statusdir.sh help"
    - run $BATS_TEST_DESCRIPTION
    - test ${status} -eq 0
    - fnmatch "*statusdir <cmd> *" "${lines[*]}"


  sd root
  sd assert-state


