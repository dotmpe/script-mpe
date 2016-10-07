
pd
  io::

    0,1,2 in/out/err

    3 passed targets OUT
    4 skipped targets OUT
    5 error targets OUT
    6 failed targets OUT

    7 arguments IN
    8 prefixes IN

  ret::

    0 passed (done)
    1 continue (ready, incomplete)
    2 unexpected error
    3 regression failure
    4 skipped
    5 bail

Generic::

    <box> <subcmd> <prefix>/ :<check>

``<check>`` target spec corresponds either an executable target, or
an alias to exutable targets.

The executables are another ``<box>:<subcmd>``, or a wrapper script providing the same.


pd run [ <prefix> | [:]<target> ]...
  TODO: translate targets to command invocation, and run at prefixes.

  - normally accept 0,3,4,5. monitor io: passed/skipped/error/failed.

  XXX: some states are directly associated with targets. Work into htd/box
  rules?

  Should selectively run targets for prefixes.

    pd run <prefix>:<target-x> <prefixes>.. :<target-y>

pd test
  - normally accept 0,4

pd check
  - normally accept 0,4

pd status
  - normally accept 0,3,4

TODO capture passed/skipped/error/failed IO and do more detailed status,
enable re-runs.

See Also
--------
- Want something more DSL like. See also htd/box rules.



