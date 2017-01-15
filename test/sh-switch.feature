
Feature: sh-switch parses switch statements from Sh scripts


  Scenario: print version
    When the user runs "sh_switch.py version"
    Then `output` contains the pattern "script-mpe\/[0-9A-Za-z\._-]*"
    And `status` should be '0'

    When the user runs "sh_switch.py --version"
    Then `output` contains the pattern "script-mpe\/[0-9A-Za-z\._-]*"
    And `status` should be '0'

    When the user runs "sh_switch.py -V"
    Then `output` contains the pattern "script-mpe\/[0-9A-Za-z\._-]*"
    And `status` should be '0'

  Scenario: no such command
    When the user runs "sh_switch.py foo"...
    Then `output` contains the pattern "Usage:"
    And `stderr` contains the pattern "No\ such\ command"
    And `status` should not be '0'


