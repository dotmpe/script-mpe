

Feature: jsotk.py is a CLI tool


  Scenario: jsotk.py is an CLI tool, with std. behaviour

    Given the project and localhost environment
    Then "jsotk" is an command-line executable with std. behaviour


  Scenario: print version

    When the user runs "jsotk.py --version"
    Then `output` contains the pattern "script-mpe\/[0-9A-Za-z\._-]*"
    And `status` should be '0'

    When the user runs "jsotk.py -V"
    Then `output` contains the pattern "script-mpe\/[0-9A-Za-z\._-]*"
    And `status` should be '0'

    When the user runs "jsotk.py version"
    Then `output` contains the pattern "script-mpe\/[0-9A-Za-z\._-]*"
    And `status` should be '0'


  Scenario: no such command

    When the user runs "jsotk.py foo"...
    Then `output` contains the pattern "Usage:"
    And `stderr` contains the pattern "No\ such\ command"
    And `status` should not be '0'



