.. include:: .default.rst

Statusdir - key-value storage service wrappers wip
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

  A wrapper for Redis/ other kv store, or also doc/JSON stores?

  @test "statusdir.sh help"
    - run $BATS_TEST_DESCRIPTION
    - test ${status} -eq 0
    - fnmatch "*statusdir <cmd> *" "${lines[*]}"

  sd root
    ..
  sd assert-state
    ..

  sd list
    ..
  sd get
    ..
  sd set
    ..
  sd del
    ..
  sd incr
    ..
  sd decr
    ..

..

    TODO: dir/files to JSON and vice versa @Dev/Dirstat-JSON

..

STATUSDIR_ROOT (~/.statusdir)
    | index/<tree>.list
    | tree/<tree>

..

    TODO: index/<name>.<ext> entries refer to tree/<name>/<entry>...

..

<tree>
    Wordlist with ' ' replaced by '/'

statusdir__file "state.json"
    Eq. $STATUSDIR_ROOT"index/$tree"

statusdir__assert [status.json] [default]
    Eq. STATUSDIR_ROOT/$1 or STATUSDIR_ROOT/$2/$1

format=[properties|sh]
    Formatter for properties (output)

- status
- record - see statusdir-record-spec unittest.

- logs TODO
- tree TODO

Sh Main
    Sort of standard <base>_main, ~_init, ~_lib seq.
    No per-func run flags, but with load and unload.
