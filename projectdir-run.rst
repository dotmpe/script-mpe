
This applies to the results of a target. Top level config is somewhat
arbitary, and can changed by parameters.
table::

  # STDOUT STDERR PASSED   SKIPPED ERROR FAILED  ID

  *        *      *        *       *     *       status
  *        *      *        0       0     0       run
  *        *      >1       *       0     0       check
  *        *      >1       0       0     0       test

  -        -      *        0-      0-    0-      check:bats-specs
  -        -      >1-note  0-      0-    0-      test:bats-specs


This is not to parametrize target.



pd proc
  Isolate run, and process results based on rules.
  Default is to copy stream, and accept any nr-of-lines: '*'
  To require any nr-of-lines: '><=', or generate fail for target.
  To clear the lines '-', and create a message: '-<log>'
  To redirect ':<IO>'.
  To exit '::<num>'.

  Combined:
    error on any lines, clear::

      0-

    copy everything and emit note (at stderr)::

      \*note

    copy everything to 'passed' and emit debug::

      \*:3debug

    move everything to 'passed' and emit debug::

      \*:3-debug

    require more than one line, then always clear, emit warning, exit 1::

      >1-warn::1

  about numbers
  To require any nr-of-lines: '><='



