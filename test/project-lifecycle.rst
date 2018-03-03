Feature: projectdoc specifies how to handle a project

  As already described in `projectdir.feature` flows will differ and need a
  way to register, getting `package.y*ml` in for this. In addition to scripts,
  Pd needs a script setting, and we can tuck this under `flows`:

     scripts/init: sh ...
     scripts/check: sh ...
     scripts/deinit: sh ...
     flows/base: init check deinit

  It doesn't provide for much of a contract
  maybe a future attribute `flow` can
  The downside is it should not reuse script ID's, and iow. base should really
  be named 'initialized' or similar. To properly identify the state. Similar
  for distributed, tested, packaged, installed. And we may be tempted to use
  more aliases. Or implicit pre-requisites.

  But within the projectdir framework it essentially describes two state
  transitions, and another script to verify it.
  We allow for 1-3 scripts per flows ID, one to enter the state represented by
  the flow ID, possibly one to verify it only, and one to revert.

  Since we now know how to enter that state, we can have flows depend on
  other flows. Any other flow will at least depend on the base state. But
  aside from 2-3 scripts, we could add any number of flow/state names as
  pre-requisites for our target state.

    scripts/init: npm install
    scripts/test: npm run test
    scripts/release: npm publish
    flows/base: init deinit
    flows/tested: test
    flows/released: tested release

  Or wrap a very simple project with minimal config:

    scripts/build: make all
    flows/base: build

  Pd should manage to record status code, and benchmark for each script.

  We could even try to construct a tree for each, using the 'base' but
  there we thead in more complex dependency graphs.


  Scenario: Initialize
    Setup project once.

    -  recursive checkout
    -  package regen
    -  excludes regen
    -  install deps
    -  make dep

  Scenario: Upgrade
    Get latest version, re-run relevant init parts.
  Scenario: Build
    Build dependencies and stacks.
  Scenario: Install
    Install build or requirements.
  Scenario: Test
    Test stacks. May require build and/or install.
  Scenario: Check
    Diagnose or doctor after init/build/test.
  Scenario: Clean
    Remove build/test artefacts, in strict mode fail on unclenables.
    To run before deleting the instance of a remote project, ie. a
    deployment or finished dev checkout.
  Scenario: Reset project
    Clean everything, make essentials again.
