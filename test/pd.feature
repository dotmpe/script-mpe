

Feature: pd


  Scenario: print version
    When the user runs "pd version"
    Then `output` contains the pattern "script-mpe\/[0-9A-Za-z\._-]*"
    And `status` should be '0'

  Scenario: no such command
    When the user runs "pd foo"...
    Then `output` contains the pattern "Usage:"
    And `stderr` contains the pattern "No\ such\ command"
    And `status` should be '1'


