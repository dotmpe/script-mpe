

Feature: a std. CLI tool


  Scenario Outline: prints version

    Given `env` 'verbosity=0'

    When the user runs "<cmd> --version"
    Then `output` contains the pattern "script-mpe\/[0-9A-Za-z\._-]*"
    And `status` should be '0'

    When the user runs "<cmd> -V"
    Then `output` contains the pattern "script-mpe\/[0-9A-Za-z\._-]*"
    And `status` should be '0'

    When the user runs "<cmd> version"
    Then `output` contains the pattern "script-mpe\/[0-9A-Za-z\._-]*"
    And `status` should be '0'

  # FIXME: not all commands handle --version, or -h
  Examples:
      | cmd              |
      #| box.sh           |
      #| box-instance.sh  |
      #| disk.sh          |
      #| docker-sh.sh     |
      #| graphviz.sh      |
      #| esop.sh          |
      | htd.sh           |
      | jsotk.py         |
      #| list.sh          |
      #| match.sh         |
      #| meta-sh.sh       |
      | projectdir.sh    |
      #| rst.sh           | 
      | sh_switch.py     |
      #| tasks.sh         | 
      #| topics.sh        | 
      #| twitter.sh       |
      #| vagrant-sh.sh    |
      | vc.sh            | 
      | x-test.sh            | 


  Scenario Outline: prints usage help

    #When the user runs "<cmd> --help"
    #Then `status` should be '0'

    When the user runs "<cmd> -h"
    Then `status` should be '0'

    When the user runs "<cmd> help"
    Then `status` should be '0'

  Examples:
      | cmd              |
      | box.sh           |
      | box-instance.sh  |
      #| disk.sh          |
      | docker-sh.sh     |
      #| graphviz.sh      |
      | htd.sh           |
      | jsotk.py         |
      #| list.sh          |
      | meta-sh.sh       |
      | match.sh         |
      #| projectdir.sh    |
      | rst.sh           | 
      | sh_switch.py     |
      | tasks.sh         | 
      | twitter.sh       |
      | topics.sh        | 
      | vagrant-sh.sh    |
      #| vc.sh            | 
      | x-test.sh            | 


  Scenario Outline: handles "no such command" situations

    When the user runs "<cmd> foo"...
    Then `output` contains the pattern "Usage:"
    And `stderr` contains the pattern "No\ such\ command"
    And `status` should not be '0'

  Examples:
      | cmd              |
      | box.sh           |
      | box-instance.sh  |
      | disk.sh          |
      | docker-sh.sh     |
      | esop.sh          |
      | graphviz.sh      |
      | htd.sh           |
      | list.sh          |
      | meta-sh.sh       |
      | match.sh         |
      | projectdir.sh    |
      | rst.sh           | 
      | sh_switch.py     |
      | tasks.sh         | 
      | topics.sh        | 
      | twitter.sh       |
      | vagrant-sh.sh    |
      | vc.sh            |
      | x-test.sh        | 

