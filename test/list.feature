Feature: list

  # Use-Case level scenarios

  # Plumbing tests
#
  @skip
  @travis
  Scenario: print names in group
    Given the current project,
    When the user runs "list.sh names local"...
    Then `status` should be '0'
    And `output` contains the patterns:
    """
    \.htdignore-clean
    \.htdignore-purge
    \.htdignore-drop
    """

  @skip
  Scenario: print names in group
    Given the current project,
    When the user runs "list.sh globs names"...
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
    When the user runs "list.sh local names"
    Then `output` should be empty.
    And `status` should be '0'

  Scenario: read entries of plain text list
    Given the current project,
    When the user runs "list.py read-list test/var/list.txt/list1.txt"
    Then `status` should be '0'

  Scenario: read entries of plain text list (2)
    Given the current project,
    When the user runs "list.py read-list test/var/list.txt/list2.txt"
    Then `status` should be '0'

  Scenario: update entries of plain text list
    Given the current project,
    When the user runs:
    """
    set -e
    mkdir -vp build/test
    cp test/var/list.txt/list1.txt build/test/list1.txt
    { echo 'Id-5:'; } | list.py update-list build/test/list1.txt
    """
    Then `status` should be '0'
    And file 'build/test/list1.txt' should have:
    """
    2017-05-14 2017-05-15 Id-1: foo
    Id-2: bar
    2008-09-02 00003: el baz
    2008-09-02 4: el baz 2
    Id-5:
    """


  # Generic CLI command conformance

  Scenario: print version
    When the user runs "list.sh version"?
    Then `output` contains the pattern "mpe"
    Then `output` matches the pattern "^script-mpe\/[0-9A-Za-z\._-]*$"
    And `status` should be '0'

  Scenario: no such command
    When the user runs "list.sh foo"...
    Then `output` contains the pattern "Usage:"
    And `stderr` contains the pattern "No\ such\ command"
    And `status` should not be '0'



