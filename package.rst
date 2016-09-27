``package.y*ml``: YAML file for project metadata
=================================================

Root level is a list, with at least one object,
required to contain a ``main`` attribute.

Items in the root list may be an object, that
may conform to the schema::

  type: <mediatype>
  id: <main-id>


Usage
-----
In various places where project metadata is needed. Ie. to enable specific
projects to offer a more abstract check/test/build/... lifecycle either
explicitly or implicitly acc. to different systems, languages, etc.

Used in conjection with ``pd`` scripts (which uses ``projects.yml``, aka. the
project document [Pdoc]).

See `test/pd-spec <test/pd-spec.rst>`_  for tested specifications.
Specifically `spec pd/0/1/6 <test/pd-spec#/pd/0/1/6>`_  that describes how the
scripts interact with the Pdoc, local package metadata and other context.


Other (optional) attributes
-----------------------------

environments
  names for environments, by convention exported as ENV, if not present.
  And used as such in project scripts.

scripts
  Mapping of named scripts for this project, used with alike named subcommands.
  Like the identical attribute in NPM's package.json.
  FIXME: Accept shell scripts, or ``pd run`` targets.

  Common names:

  check
    Scripts with pre-commit, pre-clean etc. checklist; should run fast.
    The results are used with ``pd stat``.

  test
    Scripts verifying correct functioning of project.

  init
    Script(s) for post-checkout/unpack initialization.
    Default is to (re)generate local git hooks.

  build
    Build the project from source.

  TODO: stats
    Additional scripts with results for ``pd stat``, but that would have no
    significance as a check.

  tasks
    List open tasks in project, one item per line.
    Default: ``htd list-paths | xarg radical.py``

  TODO: dist .. pack?
    Package the project.

  TODO: pub
    Publish.

  TODO: sync
    Default: make sure checkout is clean, and every local branch is at least one
    (off-disk/host) remote.


pd-script
  Like scripts, but with all values formatted as pd targets.

pd-meta
  Attribute for supplementary metadata to projectdir/doc scripts.

  All of these map to the Projectdoc schema. A description of the
  basic ones usefull in a Package file context are given here. But
  on initializing a prefix any attribute under pd-meta should be consolidated
  with the Pd attributes for that prefix. [spec pd-0.1.4.]

  init
    To override the default initialization (``pd init``, called indirectly
    by ``pd enable``)::

      pd update-meta
      pd update-hooks

  hooks
    Names of GIT client hooks. Defaults:

    pre-commit::

      pd check

  git-hooks
    A map list of names to filenames, for where to store tracked scripts.
    The keys correspond to .git/hook/* scriptnames, and if a script is not
    tracked then its default path is used and is not to be specified here.

    (Pd generates scripts is not present from other pd-meta attrs.)

  check
    Run with ``pd check *``. Default is to auto-detect.

    The script or script lines to execute for a simple checkup on the
    project. Recommended is to check for some sane state, wrt. version,
    SCM, syntax (ie. linter), etc. This can use any of the arguments
    values for ``pd run``.

  test
    Run with ``pd test``.

    The script to execute for a full test of the project.

    The degree as to wether the project is installed for such an execution
    is not specified. Except that its return code should indicate the
    result: 1 for failed, 2 for unstable, 3 for TODO, 4 for skipped.
    This can use any of the arguments values for ``pd run``.

  tasks
    Metadata for tasks (issue/ticket/time) tracking per project

    tags
      A list of tags used throughout the code to mark comments with tasks.
      Possibly only to identify local code, or also to usually to associate code
      blocks with issue/ticket/time tracker records.

  docs
    Metadata for document (wiki/specs/manual/license) tracking per project.

    tags
      A list of tags used throughout the code to link to other documents.

  trackers
    A list of objects to represent an tracker, ie. an index of tracked
    references.

    Usually projects have one bug tracker. But also local or remote
    docuemntation, specifications, planning, etc.
    XXX: this should probably be a schema on its own.

    - slug:
      url:
      tags:
      ...:


TODO: auto-detect pd check, test, init to run.
TODO: add --pd-force and/or some prefix option for pd check, test, init to run.

status
  TODO: items for weather, health (wall monitors, badges, version tracking),
  either external or local?

  XXX: Convert to STM config?
    - type: application/x-dotmpe-monitor
      static: build/monitor.json
      update:
      - pd status -
      - pd-meta -O json > build/monitor.json

  Pd scripts return status codes and lists of failed targets, that are
  cached iot. track project state. Ie. checkout modifications, failing test
  cases.

  The basic state is 'status:result'.
  Other states are recorded below 'status', and each ``<prefix>:status``.


- TODO: npm supports various script attributes that are interesting for Pd
  package schema.

  - install, and pre-/post-~ I suppose can help a bit to kick of a build.

  - prepublish (run before local 'npm install' too).

  - npm does also version bump or tags with ``npm version``

  And there is publish when uploading to NPM registry.
  stop/start, and restart.

