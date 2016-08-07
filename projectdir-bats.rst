pd
  bats-load
    - adds Bats libexec to PATH

  bats-files
    - Counts tests from Bats files

  bats-tests [ file | name | file:name | file:index ]
    - Lists tests from Bats files.

      If name given it matches the all results of a glob search.
      If none matches it is used to match the tests name.
      To use a specific mode prefix with 'bats:file' or 'bats:test'.
      The argument itself may include a globstar.

      Multiple arguments may combine arguments forms:
      '<file> <file>:\*mytest\*' etc.

      If no arguments given, or no existing paths found the default
      globs are used. Iow. test name match(es) try all files.

      The resulting list is translated to 'file:index' arguments for
      use with 'pd bats'.

  bats [ file | file:test-index ]
    - Execute tests from Bats files.

      Logs failed files and tests, to re-run failing tests.

