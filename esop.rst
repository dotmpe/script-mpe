Esop is to be a test runner with some ambitions:

.. _objectives:

- Literal specifications (Gherkin/cucumber style),
  and also literal organization of specs into components.
  With sementic references to other objects.
  Preferably with auto-renumbering, labeling. Maybe not.

- Tracking results of test runs, and combining with given specifications.
  States passed, failure, error. Probably support nesting of tests cases.
  And other features like found in TAP; bail, skip.

- Conditional evaluation of results. And optional components, or reporting per
  component. Maybe also reporting based on attached ticket/support call status.

- Management for other paremetrizations: sets (tags, or var bindings),
  matrices (euclidean sets). Maybe validation, but also see ``pd vet`` plans.

Name is short for Aesop, the Greek story teller.

Design
------
Test runners don't need a lot of verbosity.

Feature-document style testing and Behaviour driven development offer only one
facet of documentation.
It is not a place for technical or user documentation.

Literal programming style benefits from an abundance of documentation.

Dev
---
- [2016-08-27] Nothing done yet. Using Bats, TAP reports for testing now.
  With some extensions to Bats (run-at-index/range, TODO, debug).
- [2018-02-18] Some notes. Looking at literate programming.
- [2021-07-28] Not proceeding further. Have setup Gherkin features to my liking, and intend to use build tool (make/redo/grunt) to organize feature files into ordered suites, maybe do some dependencies.

- TODO: convert literal format to Bats
- TODO: capture failed tests from Bats
- TODO: add options, validation for envs or component/features
- TODO: manage options, for env, build etc. and kinds of tag sets

Misc.
-----
- See also dotmpe/x-go for parser experimenting.
- May want to ponder Py's shlex for possible source format handling.
