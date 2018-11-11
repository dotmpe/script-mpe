Redo::

  redo [TARGET...]

  redo-ood
  redo-sources
  redo-targets
  redo-whichdo TARGET

  redo-ifcreate TARGET...
  redo-ifchange TARGET...

  redo-always - Mark current target as always-rebuild
  redo-stamp - Mark to not cascade change if output/result-target is identical

`apenwarr/redo`__ uses a SQLite3 DB, ``redo.lib.sh`` accesses the DB directly to
query about build-structure (ie. get lists of deps for target directly).

Some BATS testcase `Baseline test`__ shows example use and basic expected behaviour.

Baseline tests
--------------
1. Build, redo, modify, redo; and basic commands + shell util.

   - Given one .do depends on another .do, which depends on an .sh
   - When change is made to .sh
   - And the first .do target is called: ``redo my/first.test``
   - Then both .do targets are rebuild
   - And incidentally the .do target picks up a new value from the .sh

2. Redo only targets if a dependecy actually changes

   Time-resource expensive .do target recipe
   prevention

   - Given three targets, a -> b -> c

   - Given a.do is updated (which uses redo-stamp), but functionally creates no change
   - When a redo-ifchanged of target c is requested
   - Then a.do is run, but b.do is not, and c requires no redo.

   If redo c was called instead, both a and c would have been rebult,
   but the redo-ifchange b dependecy would still not have been followed.

   Notes: redo-stamp informs the run to disregard identical results if the
   hashed input of redo-stamp matches with a previous run. On the other hand
   redo scripts can also simply bail out and cat the previous contents to
   speed up the process  if no changes are found.

3. Redo isolates env as expected, and does not re-use envs

   Given that local shell vars, like functions, are never available in a subshell.

   - When we run `redo` or `redo-ifchange` from a shell
     with ``scriptpath=...`` set
   - Then the redo script env has no such value
   - Unless we exported the var.

   All regular \*nix behaviour. [*]_
   Another little test just to easy my mind and clarify some issues:

   - Given that one .do script sources some shell profile (variables and functions)
   - Then the next .do script to run does not have access
     to either the functions or the variables.
   - Not even if exported.


.. [*] Bash can export functions for use in subshells, but does so by persisting the function to a variable first. <https://unix.stackexchange.com/questions/22796/can-i-export-functions-in-bash>





.. __: https://github.com/apenwarr/redo
.. __: test/redo-baseline.bats
