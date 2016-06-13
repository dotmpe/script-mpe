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
In various places where project metadata file is needed.
Used in conjection with ``pd`` scripts (which uses ``projects.yml``).



Other (optional) attributes
-----------------------------

environments
  names for environments, by convention exported as ENV, if not present.
  And used as such in project scripts.

pd-meta
  Attribute for supplementary metadata to projectdir/doc scripts.

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

TODO: auto-detect pd check, test, init to run.
TODO: add --pd-force and/or some prefix option for pd check, test, init to run.

scripts
  Generic ID-to-shell-lines mapping, like identical attribute in NPM's
  package.json.

  check
    For projects not directly wanting to depend on ``pd`` scripts.
    This gives the shell line(s). If present, ``pd check`` will prefer to
    run these lines, unless --pd-force.
  test
    Idem. as check.
  init
    Run to initialize a freshly unpack(ag)ed or otherwise checked out source.

    Level of setup this realizes depends per project, and the environment,
    ie. a local projectdir configuration or something else (apt, pip, brew, npm,
    etc. etc.)

  build
    ..

status
  TODO: items for weather, health (wall monitors, badges, version tracking),
  either external or local?

  Default to:
    - type: application/x-dotmpe-monitor
      static: build/monitor.json
      update:
      - pd status -
      - pd-meta -O json > build/monitor.json


