Feature: list

  Scenario: print version
    When the user runs "lst version"
    Then `output` contains the pattern "script-mpe\/[0-9A-Za-z\._-]*"
    And `status` should be '0'

  Scenario: no such command
    When the user runs "lst foo"...
    Then `output` contains the pattern "Usage:"
    And `stderr` contains the pattern "No\ such\ command"
    And `status` should not be '0'

  @skip.travis
  Scenario: print names in group
    Given the current project,
    When the user runs "lst names local"
    Then `output` contains the patterns:
    """
\.htdignore-clean
\.htdignore-purge
\.htdignore-drop
"""
    And `status` should be '0'

  @skip
  Scenario: print names in group
    Given the current project,
    When the user runs "lst globs names"
    Then `output` should match:
    """
*.cuthd
*.meta
*.py[co]
*.sw[po]
*DS_Store
*~*
.build/
.bzr/
.cllct/
.conf/
.coverage/
.git/
.gitignore-*.regex
.htdignore-*.regex
.meta/
.redo/
.svn/
.vagrant/
bower_components/
node_modules/
public/components/
vendor/
"""
    And `status` should be '0'

  @skip
  Scenario: print names in group
    Given the current project,
    When the user runs "lst local names"
    Then `output` should be empty.
    And `status` should be '0'

