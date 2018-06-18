Feature: list handles the listing of local names, and sets of names using glob patterns

  Scenario: print names in group
    Given the current project,
    And `env` 'verbosity=0'
    When the user runs "list.sh names global"...
    Then `status` should be '0'
    And `output` contains the patterns:
    """
    etc:cleanable.globs
    etc:purgable.globs
    etc:droppabl.globs
    """

    #When the user runs "list.sh names local"...
    #Then `status` should be '0'
    #And `output` contains the patterns:
    #"""
    #\.htdignore-clean
    #\.htdignore-purge
    #\.htdignore-drop
    #"""

  Scenario: print names in group
    Given the current project,
    And `env` 'verbosity=0'
    When the user runs "list.sh globs names"...
    #Then `output` should match:
    #"""
    #"""
    And `status` should be '0'

  Scenario: print names in group
    Given the current project,
    And `env` 'verbosity=0'
    When the user runs "list.sh local names"
    Then `output` should be empty.
    And `status` should be '0'

  Scenario: read entries of plain text list
    Given the current project,
    And `env` 'verbosity=0'
    When the user runs "list.py read-list test/var/list.txt/list1.txt"
    Then `status` should be '0'

  Scenario: read entries of plain text list (2)
    Given the current project,
    And `env` 'verbosity=0'
    When the user runs "list.py read-list test/var/list.txt/list2.txt"
    Then `status` should be '0'

  Scenario: add entry to plain text list
    Given the current project,
    And `env` 'verbosity=0'
    Given cleanup "build/test/list1.txt"
    # FIXME: multiline exec would be nice to have
    Given a file "test-list-feature.sh" containing:
    """
    set -e
    mkdir -vp build/test
    cp test/var/list.txt/list1.txt build/test/list1.txt
    { echo 'Id-5: tralala'; } | list.py update-list build/test/list1.txt
    """
    And a file "build/test/list2.txt" containing:
    """
    2017-05-14 2017-05-15 Id-1: foo
    Id-2: bar
    2008-09-02 00003: el baz
    2008-09-02 4: el baz 2
    Id-5: tralala
    """
    When the user runs "sh test-list-feature.sh"
    When the user runs "diff -bqr build/test/list{1,2}.txt"...
    Then `status` should be "0"
    # FIXME: something going on here. what? file-get-contents has no cache.
    #Then file 'build/test/list1.txt' should have:
    #"""
    #2017-05-14 2017-05-15 Id-1: foo
    #Id-2: bar
    #2008-09-02 00003: el baz
    #2008-09-02 4: el baz 2
    #Id-5: tralala
    #"""
    Then cleanup "test-list-feature.sh"

 @skip
 Scenario: TODO: update entry to plain text list
    Given the current project,
    And `env` 'verbosity=0'
    Given a file "test-list-feature-2.sh" containing:
    """
    set -e
    { echo '00003: oops'; } | list.py update-list build/test/list1.txt
    { echo '4: oooops II'; } | list.py update-list build/test/list1.txt
    """
    When the user runs "sh test-list-feature-2.sh"
    Given a file "build/test/list3.txt" containing:
    """
    2017-05-14 2017-05-15 Id-1: foo
    Id-2: bar
    2008-09-02 00003: oops
    2008-09-02 4: oooops II
    Id-5: tralala
    """
    Then the user runs "diff -bqr build/test/list{1,3}.txt"
    Then cleanup "test-list-feature-2.sh"

  # Generic CLI command conformance

  Scenario: print version
    Given `env` 'verbosity=0'
    When the user runs "list.sh version"?
    Then `output` contains the pattern "mpe"
    Then `output` matches the pattern "^script-mpe\/[0-9A-Za-z\._-]*$"
    And `status` should be '0'

  Scenario: no such command
    Given `env` 'verbosity=0'
    When the user runs "list.sh foo"...
    Then `output` contains the pattern "Usage:"
    And `stderr` contains the pattern "No\ such\ command"
    And `status` should not be '0'

