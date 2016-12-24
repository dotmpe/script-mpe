Feature: list

  Scenario: print version
    When the user runs "lst version"
    Then `output` contains the pattern "/script-mpe\/[0-9A-Za-z\._-]*/"

  Scenario: no such command
    When the user runs "lst foo"...
    Then `output` contains the pattern "/Usage:/"
    And `stderr` contains the pattern "/No\ such\ command/"
    And `status` should not be '0'

  Scenario: print names in group
    Given the current project,
    When the user runs "lst names local"
    Then `output` should match:
    """
.htdignore-cleanable
.htdignore-clean
.htdignore-purgeable
.htdignore-purge
.htdignore-droppable
.htdignore-drop
"""

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
.composer.lock
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

  @skip
  Scenario: print names in group
    Given the current project,
    When the user runs "lst local names"
    Then `output` should be empty.

