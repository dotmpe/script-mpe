Pd Specs
========
:Created: 2016-01-24
:Updated: 2018-01-20

Pd - unified project checkout handling.

- Consolidation, registration of projects into projectdirs/-docs.

:FIXME: test wether staged, unstaged changes or stash are recognized as dirt
   or cruft. Build some tests.
:FIXME: need to consider submodules dirt/cruft too before disabling parent checkout.
:TODO: Sub-commands should be documented in projectdir.sh (cq. man sections).
:TODO: submodule support
:TODO: annex support
:TODO: reload bg command.
:TODO: compile packaged scripts from literate style scripting like below. Package for subcommands, and with relations/decorations, with embedded scripts or to annotated external scripts.

- Annotation like this should eliminate scattered metadata files
  like .pd-test
  and consolidate the settings into a single definitive document.
  And sync with local package metadata.

  For now the entry point for this is package.yaml.

  See package_ also for some related TODO's.
  See below for some sketchups on pd subcommands,

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


Workflows
---------
- `Feature: projectdir is a tool to handle projects as groups <test/projectdir.feature>`__

  - `Feature: projectdoc specifies how to handle a project <test/project-lifecycle.feature>`__

- `Other stack/project dev scenarios <test/dev.feature>`_
- For more simple installations of third-parties, see also tools_ schema.


Related source files
---------------------
- Frontend: projectdir.sh_.
- Extensions: ``projectdir-*.inc.sh``.
- YAML store backend: projectdir-meta_ (Python script for handing Pdocs).


Components
------------
pd
  Use cases
    1 Enable a known prefix, or reassert
      * checkout (1.1), add remotes (1.2)
      * track enabled status globally, or per host (1.3)
      * checks out default branch, or other reference
      * regenerate GIT hooks if available per project
      * track submodules to initialize in similar way
      * restore selected or all local prefixes to recorded status
    2 Check prefix status
      * report on tracked file status
      * optionally include untracked, and untracked ignored files
      * TODO: report on stash
      * report on up-/downstream sync status, require sync of all branches with
        at least one remote
    3 Create or update a prefix record from an existing checkout
      ..

  Internal functions
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

  States
    | check
    | scm
    | deps
    | test
    | build
    | install

  Subcommands
    pd status
      With no args, set to current prefix, or prefixes at current location.
      TODO: Add some named states to run for prefixes.

      And with (each) prefix, run ``:scm-check``.

    pd run
      Execute one or more targets at prefix. Track all Pd outputs,
      count lines and keep verbosity minimal unless requested.
      Fail on any skipped, errored or failed target.

      bats-spec
        ..
      bats
        - dependencies bats
        - ``./test/*-spec.bats | script-bats.sh colorize``
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

    pd exec
      Isolate run, and handle multiple prefixes.
      Runs targets, records status.

    pd install
      TODO: without args, detect+install any deps. Detect is actually
      install-dependencies.sh ?

      With '.', install local project. Or specify single tool/dep directly.

      bats
        - installs bats BATS_VERSION PREFIX
      jjb
        .. etc.

    pd test
      Run test scripts for project.
      Run failed or error targets if found, or run all tests.

      Detects some standard build types, override
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

    pd update
      With no args, set to current prefix, or prefixes at current location.
      And with (each) prefix, update Pd, default updates.

      Or updated named status.

    pd ls-sets
      List named sets.

    pd ls-targets [ NAME ]...
      List targets for given named set, for current prefix.
      If none is defined, the list is generated using autodetection.
      See ``ls-sets`` for the available set names.

    pd show [ PREFIX ]...
      Pretty print Pdoc record and package main section if it exists,
      for each prefix.


.. _projectdir.sh: ./projectdir.sh
.. _projectdir-meta: ./projectdir-meta
.. _package: ./package.rst
.. _vc.sh: ./vc.sh
.. _tools: ./schema/tools
