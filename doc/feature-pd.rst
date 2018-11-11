Pd: specs for pdir and pdoc components
==============================================================================
Pdoc, or how to track projects
''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''

Design
-------
  . Some examples
  and introduction:

  How to create a flow:

    scripts:
      init: sh ...
      check: sh ...
      deinit: sh ...
    flows:
      base: init check deinit

  It doesn't provide for much of a contract, but given a profile for names in a
  project lifecycle it provides the basis for a sort of state machine look at
  the projects phase. We only need to record some result bits.

    env: . $ENV
    states:
      base: 1
      test:
        base: 1
        units: 0
        features: 1
    benchmark:
      test:
        base: 123
        units: 99
        features: 24

  We want detailed reports on state and cost of state, but not of the project
  components itself. How project components tie to the different states is
  a matter of information level to be provided by another system but not within
  current scope. Pd keeps a hierarchical status number, and benchmark numbers.

  Choosing mode is an essential implementation that needs to be faultless to
  accurately asses a projects state. If the profile is faulty, the build/test/etc.
  report is worthless. And unless the project hosts are completely homogenous,
  such breakage will happen.

  The env key is a convenience, to provide a unified profile to the scripts. But
  also to sanitize and check.
  Such sophistications include/bring profile parameterization, derrivation,
  composition, etc.

  In practice, even with a simple single profile we still need to tackle the
  different script envelopes (metadata formats), and how they are properly
  executed. For simplicity let 0.0.1 just deal with one side of the story
  using plain sh or whatever user-land command per project req'ments.


  Now lets get down to the script/flow/... keys and surrounding profile.

  And some defaults. Note a flow value is a tuple with to-state, verify-state and
  destroy-state phases and maybe more. Flows cant name commands directly but
  refer back to scripts. Still certain scripts named as flow have a certain
  state associated once they execute correctly, and also cannot be defined as
  flow themselves.

  Defaults::

    env: . $(pd choose env)

    scripts:
      init: $(pd choose-script init)
      .. etc

    flows:
      _1: [key=val... | $ENV] init [check] deinit
      _2: build test
      _3: _2 install
      _4: _2 package distribute
      base: _1
      ci: _2
      cd: _2

    flow-names:
      base: Root
      init: Initalized
      check: Checked
      deinit: De-initialized


  And

    env:
    . ~/.local/etc/profile/$ENV_NAME.sh
    scripts:
      init:
      deinit:
      build:
      test:
    flows:
      _1: key=val $_1_ENV init deinit

  components: other flows that represent optional parts of the project,
    each having inidivual state (compile/test/build).
    Ie. setting Pd-package-Components changes the the parts considered by the
    flows.

  The downside is it should not reuse script ID's, and iow. base should really
  be named 'initialized' or similar. To properly identify the state. Similar
  for distributed, tested, packaged, installed. And we may be tempted to use
  more aliases. Or implicit pre-requisites.




Definitions
------------
Projectdir [Pd]
  - directory of prefixes to checkouts, and with a Projectdoc on path
Projectdoc [Pdoc]
  - metadata file listing prefixes repo/remotes etc.
Prefix
  - A directory below a Projectdir with package metadata files and/or SCM dirs.
Workspace
  - Per-host/context and/or nested Workdirs (ie. home, projectdir, public-html,
    user-conf), or instances or unique basedir (local volumes, remote mounts,
    synced dirs). Contexts as in levels, modes of user access.
Current (working) dir [CWD]
  - From where a script is run, relative to some workspace.
Target
  - a specification of a command run on a prefix.
Cruft
  - Unrecognized or cleanable, but unignored files. Ie. swap files, cache,
    build artefacts.
  - Usually ignored (e.g. gitignores) but when removing checkouts, all files
    below should be considered.
Dirt
  - Uncommitted or unsynchronized SCM elements. Ie. modified, staged, stashed.
  - Before removing checkouts first always a check and confirmation should
    be required before purging local unmerged branches, stashed changes,
    dirty files, etc.

SCM (clean/dirty/crufty) handling depends on vc.sh_ script.
