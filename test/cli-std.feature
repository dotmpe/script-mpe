

Feature: a std. CLI tool


  Scenario Outline: prints version

    When the user runs "<cmd> --version"
    Then `output` contains the pattern "script-mpe\/[0-9A-Za-z\._-]*"
    And `status` should be '0'

    When the user runs "<cmd> -V"
    Then `output` contains the pattern "script-mpe\/[0-9A-Za-z\._-]*"
    And `status` should be '0'

    When the user runs "<cmd> version"
    Then `output` contains the pattern "script-mpe\/[0-9A-Za-z\._-]*"
    And `status` should be '0'

  Examples:
      | cmd |


  Scenario Outline: handles "no such command" situations

    When the user runs "<cmd> foo"...
    Then `output` contains the pattern "Usage:"
    And `stderr` contains the pattern "No\ such\ command"
    And `status` should not be '0'

  Examples:
      | cmd |


