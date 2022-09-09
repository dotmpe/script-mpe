Project Dev/Build Scripts
=========================

Build_ to deal with projects.

, ie. `Project Dev Checks`_ and subdocs
  `Project Dev/Build Scripts`_ and `Project Test Scripts`_

TODO: split to:

build.lib.sh for package targets; build, test script-helpers
dev.lib.sh for TDD, source processing and more SCM integration
list.lib.sh for watch, list, test code


TDD
---
Best enabled by a file-system watch utility, which come in various forms.
But even a simple polling shell script will do.

The important thing is choosing the workflow. And turning it on.

- Test everything, re-test failures
- Test file after changes

Without either, the build will break. See <project.rst#tdd> for a more high
level HOWTO.

Given package metadata about test-file locations, and some setup to provide a
test-harnass for each test-filetype.\ [#]_ When the basename of our source-file
matches a test-file, then we can execute that and note the status. Succes
indicates the changes to the source-file at least are OK. There can be made
some more checks to run, like a sort of git-pre-add-hook, and then the source-
file is staged for commit.

The test-file, if changed, could be staged too. But that seems more like an
explicit action before commit. Committing is currently out of focus for this
workflow, but at a higher level of integration can well be part of it.
For now it is an explicit developer action that should not be impeded (too much).

TODO:

Here is the metadata setup for the current package, using htd-build.lib.

The `test` target tries to be smart about which tests its goes through, with
`tdd` a loop is started at the terminal monitoring for changed files.
While both record status with a central file, upon commit its easy to check and
even summarize for the commit log.

::

    package_pd_meta_test_mode=test_scm
    package_scripts_test="lib_load build && exec_watch_scm $package_pd_meta_test_mode"

    # XXX: test-scm mode params:
    package_pd_meta_checks_warn=
    package_pd_meta_checks="test_clean"
    package_pd_meta_on_test_nok="build_retest/build_reset \"$1\"
    package_pd_meta_on_test_ok=""


Because we don't have detailed source information, individual specific modules
will need to fill in for certain environments, languages and test forms.
The bare-bone shell approach allows to easily extend and customize the
default setup. At the same time that it helps to standardize project setup
further while increasing its complexity and potential.

In above package_pd_meta_* switch the exec-watch-scm and other routines in
build.lib.sh


..

    OK: +script-mpe package:tests: lists test script files for given component build.lib.sh#project_tests
    OK: +script-mpe package:test: exec test scripts for given component build.lib.sh#project_test
    OK: +script-mpe package:test-scm: exec tests for changed files build.lib.sh#project_test

    TODO: central tracklist for comp/script status, ie. {tested,retest}.list
    TODO: set test-scm post-test checks, and stage-mode; either .git/index or separate list, ie. tested.list

.. [#] TODO: document package keys for build, link to docs


Dependency based build system
-----------------------------


Travis
-----------
Sequence

- [Apt, Services, Clone+Submodules, Env, Cache setup]
- (Before) Install
- (Before) Script
- After Success, Failure
- After Script
- Before Cache

# Travis env:
# TRAVIS_TIMER_ID=(hex)
# TRAVIS_TIMER_START_TIME=1544134348250991906
#                         1544136294. ie. split at end-9
# TRAVIS_TEST_RESULT=(0|...)
# TRAVIS_COMMIT
# TRAVIS_LANGUAGE=(python|...)
# TRAVIS_INFRA=(gce|...)
# TRAVIS_DIST=(trusty|...)
# TRAVIS_BUILD_STAGE_NAME=?
# TRAVIS_PULL_REQUEST=(true|false)
# TRAVIS_STACK_TIMESTAMP=(ISO DATETIME)
# TRAVIS_JOB_WEB_URL=https://travis-ci.org/dotmpe/script-mpe/jobs/$TRAVIS_JOB_ID
# TRAVIS_BUILD_WEB_URL=https://travis-ci.org/dotmpe/script-mpe/builds/$TRAVIS_BUILD_ID
# TRAVIS_BUILD_NUMBER=[1-9][0-9]*
# TRAVIS_JOB_NUMBER=$BUILD_NUMBER.[1-9][0-9]*
# TRAVIS_BUILD_ID=[1-0][0-9]*
# TRAVIS_JOB_ID=[1-0][0-9]*

Logging
-------
::

    $sd_logsdir/builds-$PROJ_LBL.list
    $sd_logsdir/results-$PROJ_LBL.list

Commands in ``u_s-dckr.lib.sh`` (`U-s:bin/u-s`):

- ledge-showbuilds
- ledge-exists
- ledge-pull
- ledge-listlogs
- ledge-sumlogs
- ledge-refreshlogs
- ledge-pushlogs

Logs are kept in a docker volume committed to an image. To avoid sync issues
each projects' logs are kept in a separate container, but may be merged by a
coordinated build.

The above commands operate on that one image and pull or push logs from the
local sd-logsdir spec.

List all tags for image::

  docker-hub tags dotmpe/ledge

- FIXME: GIT commit-amend and push-force lets travis rebuild correctly without
  additional commit, however Travis still believes its git-commit-range starts
  at the last known commit sha (which has been undone).

..
