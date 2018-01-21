Feature: Project Lifecycle workflow

  Background:
    A collection of steps to represent for the most generic workflow.
    But it may want some modes/addons.
    Ie.

    - build+install
    - build+test+install
    - create+delete

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

