
pd
  io::

    0,1,2 in/out/err
    3 passed targets
    4 skipped targets
    5 error targets
    6 failed targets
    7 arguments

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
- htd/box rules::

  # ID       RET
  pd:status  0,3,4  @stat
  pd:test    0,4    @test
  pd:check   0,4    @stat @test @check
  pd:clean   0

  # Separate cmdname from status?

- target spec, wrapper or box. box subcmds::

    pd:status
    box:target:*
    :<local-target>
    <other-box>:<remote-target>

  build in wrappers::

    :-*:
    :!
    :sh:
    :python:
    :bats
    :bats:*
    :bats-specs:
    :mk-test
    :grunt-test
    :grunt:*
    :make:

  each invocation creates a similar named status (at prefix(es)).
  this status is an object holding the return status, and also the amount of
  targets returned on IO.

  It is recorded into the Projectdoc under a status key prefix provided
  for by the target, under the attribute 'status' of the Pd root or prefix.

  This way, any kind of status can be tracked for a project. As long as it
  boils down to an invocation of a box function or a wrapped external command.

  Some targets may take arguments. The specification is entirely up to the
  specific target (ASCII, cannot contain whitespace).
  ideally targets for a prefix are specificed by the project itself.
  to differentiate targets from existing paths a ':' prefix is allowed.

  Targets produce IO lines and return codes, while usually changing the project
  or repeating some procedure to reach a certain goal, and then verify it.
  To track project state Pd defines some elementary states associated with
  the lifetime of a project. The goal is to ease SCM handling and basic project
  tasks like syntax checking and test reporting.

  At some point this kind of composite state gets kind of fuzzy. Do we want
  a project to test correctly before we commit it? Which tests should run?
  Or do we care at all if a project checks out and initializes correctly.

  To forego the flexible but repetitive box function setup, why not do a little
  rule kernel with its own DSL. Like above syntax. Very Sh inspired.

  pd status
  pd status :init :stat :check :test
  pd check
  pd test

  :status:init ->
    ?:enabled
      && ?:test:-d
        && :initialize
        || :enable
      || :deinit:

  :stat ->
    ?:enabled
      && :init :clean ?:check ?:test
      || :clean

  :test ->
    ?:enabled
      && ?:script:test
        && :script:test
        || :default:test

  :check ->
    ?:enabled
      && :init
        ?:script:check
        && :script:check
        || :default:check

  Each
    a check for an Pd attribute,
    or an target (seq) execution to update an attribute.
  This means the engine controls
  validating wether the attribute is up to date.

  The conditions all depend on attributes.


  The syntax expresses conditional branches from one target to (an)other(s).
  After parsing, each rule is re-evaluated by the engine to return the next
  invocation. Unless an unexpected situation is reached before that,
  the caller continues invoctions until all the result into a zero exit status
  code.

  Concerned metadata includes schemas under 'status', 'script' and 'targets'
  attributes.
  Targets are registered globally and per project. And parsed upon
  consolidation into Pd compatible targets.

  Initially the goal is to get ``status:result`` to 0 by getting
  each ``status:<prefix>:result`` to 0. Then check, and test idem ditto.
  This is by resolving each to executable targets, and get a
  success state for all these.

  There are other detailed states we want to look at instead of return code.
  Also we may want to restrict or relax the standard return code
  matching, eg. depending on IO or settings.

  The subcmds init, stat, test and check each runs its respective status rules.
  The difference is these are always updated, unless the cached/recorded value
  is requested.

  Targets below

  All rules evaluate from the projectdir root, with a prefix as argument.
  The engine handles each target as one step, evaluating the return code and
  IO streams. With the DSL new targets are made up constructed entirely of
  expressions to metadata and other targets.

  :deinit
    ?:enabled
      && ?:sh:test:-d:$prefix/

