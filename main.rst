Intro
-----
This is a heavy work in progress.

Background
----------
Main is a number of things, here we want to consider the steps leading up to
the "main task" and what happens after.

Most importantly it is a concept dealing with diffent evaluation contexts,
or getting into and out of one after having performed a particular task.

- map a user command, alias, or other evocation (command-line) into an actual
  executable and argument sequence.

For `c` language its executable entrypoint is
``int main(int argc, char *argv[])`` or even ``void main(void)``, for Python it
is a global variable state ``__name__ == __main__`` in a module, and for
other languages/environments it may be even more obscure. Ie. PHP, Groovy, NodeJS
just like shells all have facilities for getting the originally evocation line,
and to get and parse arguments.

Using the shell, we first have several options in executable names:

- exec-name (an executable on PATH, or ./exec-name)
- func-name (an function loaded for this shell)
- alias-name (an interactive-shell alias, for a command-line prefix-part)

Initializing the shell usually goes in two phases: `profile` and `rc` for all
login (console or SSH sessions), while non-login shells skip the profile and go
directly for the `rc` files. Profiles should be written to run in non-user
shells, and ``export`` variables to be used in other env. `rc` should customize
the user shell env.

Based on this, we can use functions and aliases to get access to any kind of new
env: source files; get new vars or functions, update lookup-paths, etc. But
between our scripts we need to ensure our env stays consistent.

See HT:draft/2019-02-19,env-d.rst for even more background on shell scripting,
and using shells as execution environments for users or agents.

Design
------
::

  $ <exec-name> <args...>
  $ <grp>-<handler> <rest...>

`grp` corresponds to a Composure group prefix, but that may not be appropiate
to alias (but should in theory allow to map every function in such group).
To "publish" specific commands `grp` and `exec-name` can be bundled for resolve.

``<grp>/main.inc``
  Both cases require a handler for execution, and these are expected at
  ``<grp>-main`` or ``<grp>-<exec-name>``, except for some minor specific
  details.

XXX: For the `c` group, besides being the default if left empty, the
script-alias `composure`` can be set (ie. for ``exec-name``)

Specs
-----
`main.lib.sh`:
  Main: CLI helpers; init/run func as subcmd

  ``main_subcmd_run <args...>``

  lots of option, lookup, debug, pre/post init/deinit load/unload stuff things
  happening.

  See also other main and box::

    $ <exec-cmd-name> <sub-cmd-name> <args...>
    <base>__<cmdid> <subcmdid> <args...>

  - ``$ <box> <handler-name> ...``
  - ``$ <box> <lib-name> <func-name>``


`main.inc.sh`::

  case "$base" in
    -* ) # Ignore (accidental) source of script
    $scriptname ) main $*

Composure/main
  Resolve
    `c-resolve-f` is a little helper to get the function name to map the call to.
    For `<arg1...argn>` it starts at `<arg1>-<arg2>` and keeps concatenating
    `<arg3...argn>` while the name exists as function.

    If `grp` is default ``c`` and `exec-name` is ``main``, we would recurse to
    `c-main` possibly endlessly in a loop. Unless the next arguments match ie.
    `c-main-new-entry`.

  TODO: Recursing `c-main` for the same group is caught as an error.

  Execute
    Some care is needed with other accidental corresponding exec-names,
    for example ``sh``, other shell or interpreters, user scripts.

    Also, potentially exposing any function makes little sense except for
    certain ones.
    But more importantly it is not possibly to foresee all kinds
    of script load/unload, while we can generate certain execution handlers
    dynamically ie. ``c-main-new-entry``

    So for any exec-name a corresponding composure function to handle the
    command should exist. To handle init and deinit as fit. And to really
    execute any subcmd func from ``<grp>`` as sub-commands, add the `grp` value
    to ``c_main...`` as well.
    Checks are kept down, and left to the handlers so the
    load/unload can be as fast as can be.

    ``sh-fooo-bar-baz -> main.sh``
      ::

        c-main sh foo bar baz "$@"
          c-resolve-f sh foo bar baz "$@"
            Simple hyphenated function resolve
          shift $c
          $f "$@"

        <> sh "$@"
        <> sh-foo

c-main:
  ..

ht-main:
  ..

----

main-bg
  Some user-scripts have a 'meta' command that interactis with a metadata
  backend, a python script more suited for processing ie. YAML or database
  interaction.

  The ``--background`` option starts a re-usable single-threaded? background
  server instance (using twisted).

  The background process stays attached to the tty, so use a separate shell or
  job control for the invocation (ie. prepend ``shell -c`` or append ``&`` to
  the line).

main-bg-writeread
