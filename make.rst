Make main-make.lib main-defs.lib: reduce boilerplate on shell scripts

``make.sh`` generates a "main-entry" point, and load, init and subcmd load/unload
handlers for shell scripts. These handlers use ``main.lib.sh`` to map command
lines/arguments to command handlers in the form of shell functions.

The aim is to reduce boilerplate and increase reusability of specific script
parts in addition to ``main.lib`` and ``tools/*/parts`` etc. By preprocessing
the scriptfile before evaluation, the settings can be reduced to to a minimum:

main-local
    Additional local variables for the generated <base>-main function.

main-bases
    Provide additional namespace bases if necessary.

main-init
    Provide a function script to run just after main's local vars are set,
    this may preprocess the arguments and abort by return status.
    TODO: allow to rewrite arguments entirely, iso. of jsut passing first n

main-lib
    Provide a function script to run by main just before deferring to
    main_subcmd_run, and abort.

(main-init-env)
  Set INIT_ENV and INIT_LIB to script parts and user libraries respectively.
  These are bot provided to ./tools/main/init.sh.

main-load{,-flags}
  Provide script and/or case/esac keys to handle load for specific subcmd.

main-unload{,-flags}
  Undo or cleanup for main-load.

Compilation
-----------
::

    make_echo=1 <base>.sh > <base>.shc

Formatting
----------
- The script sequences need to use backward slashes to mark all lines in each
  main-* setting block, or use the ``MAKE-HERE``-marker.
- The script sequences cannot use stray ' (single quote) characters.

Scripts using MAKE-HERE use a slightly different parser, that requires to escape
variables but that don't require line-continuations (trailing backslashes).

The script fragments are stored as '-delineated strings. So in order to use
single quotes in the main-make scripts, these need to take in consideration its
occurence effectively ends the string it is embedded in.
Ie, to use single quotes, quote them with ``"`` and obviously escape variables
if given in these parts::

    # Do'"'"'s and don'"'"'ts
    echo '"'\$VAR'"'

Files
------
- With ``MAKE-HERE``: x-test-make-here.sh
- Without; x-test-make-preproc.sh, x-test-make.sh
- main.lib test boilerplate: x-test.sh

..
