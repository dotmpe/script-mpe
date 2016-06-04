:Created: 2016-01-24

Pd - unified project checkout handling.

| Projectdir - directory of prefixes to checkouts, and with a Projectdoc on path
| Projectdoc - metadata file listing prefixes repo/remotes metadata

Started docs for some projectdir actions.
Metadata schema is in package.rst and projectdir-meta docs.

Most docs, TODO points are in projectdir-meta for now.
Migrate here upon testing.
See also package.rst for related package.yml schema.

:TODO: Sub-commands should be documented in projectdir.sh (cq. man sections).
:TODO: testing
:TODO: submodule support
:TODO: annex support

:TODO: reload bg command.
:FIXME: use shm or equiv. for temp file I/O

:TODO: compile packaged scripts from literate style scripting like below. Package for subcomamnds, and with relations/decorations, with embedded scripts or to annotated external scripts.

- Annotation like this should eliminate scattered metadata files
  like .pd-test
  and consolidate the settings into a single definitive document.

  For now the entry point for this is package.yaml.
  See package.rst also for some related TODO's.
  See below for some sketchups on pd subcommands,

pd
  - annotate ./projectdir.sh

  First some internal functions.

  load
    Internal function, optional attribute pre each command with flags::

      p: follows d or y, look for package_id value.
      d: require and set prefix dir at current working dir
      y: look and go to dir with projectdocument (prefix root),
        set prefix if there was one at current working dir
      f: TODO: intialize failure output stream
      b: setup background pd-meta for this command

  unload
    If failed env is present, give some info about that and fail exec.
    ::

      b: exit pd-meta bg process

  Subcommands:

  pd status
    With no args, set to current prefix, or prefixes at current location.

    With (each) prefix, run ``:scm-check``

  pd run
    Takes single argument specs, representing predefined command invocations.

    bats-spec
      ..
    bats
      - dependencies bats
      - ``./test/*-spec.bats | bats-color.sh``
    mk-test
      - make test
    git-versioning
      - git-versioning check
    sh:*
      ..
    scm-check
      TODO:
      - scm-clean
      - scm-sync
    scm-clean
      - vc stat
    scm-sync
      TODO:
      Modal command with DRY_RUN.
      Try update and determine ahead/behind/missing per remote.

  pd install
    TODO: without args, detect+install any deps. Detect is actually
    install-dependencies.sh ?

    With '.', install local project. Or specify single tool/dep directly.

    bats
      - installs bats BATS_VERSION PREFIX
    jjb
      .. etc.

  pd test
    Run test scripts for project. Detects some standard build types, override
    with package.yml? Runs shell scripts, and passes ':'-prefixed arguments to
    pd run.
    TODO: 1 - failed, 2 - unstable, 3 - TODO, 4 - skipped, 5 - re-run?

  pd check
    Idem as pd test, but for check attributes.

  pd init
    Initialize a fresh upack(ag)ed/checkouted source dir to a projectdir prefix
    record (creating or updating existing).
    TODO: write a package skeleton as well, or sync with existing.
    TODO: 1 for (unresolved failure), 2 for continue after pre-rq

  pd vet
    TODO: validate package metadata

  pd build
    TODO: In place build, requires access to PATH (or export PATH?)
    Function again varies per project goals.

  pd h(t)docs / web-docs
    TODO: Setup web server (container) to local documentation.

  pd monitor
    setup ncurses or HTTP+HTML wall monitor display, see package status.

  pd spec
    XXX: check that a certain specification is provided by the project?


