

Feature: pd


  @skip.travis
  Scenario: prints version
    When the user runs "./projectdir.sh version"
    Then `output` contains the pattern "script-mpe\/[0-9A-Za-z\._-]*"

  @skip.travis
  Scenario: no such command is an error
    When the user runs "./projectdir.sh foo"...
    Then `output` contains the pattern "Usage:"
    And `stderr` contains the pattern "No\ such\ command"
    And `status` should be '1'


